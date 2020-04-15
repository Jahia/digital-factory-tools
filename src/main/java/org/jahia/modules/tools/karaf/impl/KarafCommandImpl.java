/*
 * ==========================================================================================
 * =                   JAHIA'S DUAL LICENSING - IMPORTANT INFORMATION                       =
 * ==========================================================================================
 *
 *                                 http://www.jahia.com
 *
 *     Copyright (C) 2002-2020 Jahia Solutions Group SA. All rights reserved.
 *
 *     THIS FILE IS AVAILABLE UNDER TWO DIFFERENT LICENSES:
 *     1/GPL OR 2/JSEL
 *
 *     1/ GPL
 *     ==================================================================================
 *
 *     IF YOU DECIDE TO CHOOSE THE GPL LICENSE, YOU MUST COMPLY WITH THE FOLLOWING TERMS:
 *
 *     This program is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     This program is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 *
 *     2/ JSEL - Commercial and Supported Versions of the program
 *     ===================================================================================
 *
 *     IF YOU DECIDE TO CHOOSE THE JSEL LICENSE, YOU MUST COMPLY WITH THE FOLLOWING TERMS:
 *
 *     Alternatively, commercial and supported versions of the program - also known as
 *     Enterprise Distributions - must be used in accordance with the terms and conditions
 *     contained in a separate written agreement between you and Jahia Solutions Group SA.
 *
 *     If you are unsure which license is appropriate for your use,
 *     please contact the sales department at sales@jahia.com.
 */
package org.jahia.modules.tools.karaf.impl;

import static org.apache.karaf.shell.support.ansi.SimpleAnsi.*;

import org.apache.commons.lang.StringUtils;
import org.apache.karaf.shell.api.console.Session;
import org.apache.karaf.shell.api.console.SessionFactory;
import org.jahia.modules.tools.karaf.KarafCommand;
import org.osgi.service.component.annotations.Activate;
import org.osgi.service.component.annotations.Component;
import org.osgi.service.component.annotations.Deactivate;
import org.osgi.service.component.annotations.Reference;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.security.auth.Subject;
import java.io.ByteArrayOutputStream;
import java.io.PrintStream;
import java.security.Principal;
import java.security.PrivilegedExceptionAction;
import java.util.Arrays;
import java.util.concurrent.*;

@Component(service = KarafCommand.class, immediate = true)
public class KarafCommandImpl implements KarafCommand {

    private static final Logger logger = LoggerFactory.getLogger(KarafCommandImpl.class);

    private static String[] CONSOLE_CONTROL_STRINGS = new String[] { COLOR_CYAN, COLOR_DEFAULT, COLOR_RED,
            INTENSITY_BOLD, INTENSITY_NORMAL };
    private static String[] CONSOLE_CONTROL_STRINGS_REPLACEMENT = new String[CONSOLE_CONTROL_STRINGS.length];

    static final Long SERVICE_TIMEOUT = 5000L;

    static {
        Arrays.fill(CONSOLE_CONTROL_STRINGS_REPLACEMENT, StringUtils.EMPTY);
    }

    private static String cleanupOutput(String output) {
        return StringUtils.replaceEach(output, CONSOLE_CONTROL_STRINGS, CONSOLE_CONTROL_STRINGS_REPLACEMENT);
    }

    private SessionFactory sessionFactory;

    private  ExecutorService executor;

    @Reference
    public void setSessionFactory(SessionFactory sessionFactory) {
        this.sessionFactory = sessionFactory;
    }


    @Activate
    public void activate() {
        this.executor = Executors.newCachedThreadPool();
    }

    @Deactivate
    public void deactivate() {
        executor.shutdown();
    }

    private void waitForCommandService(String command) {
        // the commands are represented by services. Due to the asynchronous nature of services they may not be
        // immediately available. This code waits the services to be available, in their secured form. It
        // means that the code waits for the command service to appear with the roles defined.

        if (command == null || command.length() == 0) {
            return;
        }

        int spaceIdx = command.indexOf(' ');
        if (spaceIdx > 0) {
            command = command.substring(0, spaceIdx);
        }
        int colonIndx = command.indexOf(':');
        String scope = (colonIndx > 0) ? command.substring(0, colonIndx) : "*";
        String name  = (colonIndx > 0) ? command.substring(colonIndx + 1) : command;
        try {
            long start = System.currentTimeMillis();
            long cur   = start;
            while (cur - start < SERVICE_TIMEOUT) {
                if (sessionFactory.getRegistry().getCommand(scope, name) != null) {
                    return;
                }
                Thread.sleep(100);
                cur = System.currentTimeMillis();
            }
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    public String executeCommand(String command, final Long timeout, final Boolean silent, final Principal... principals) {
        if (command != null && command.startsWith("dx:")) {
            // workaround to alias "jahia" scope with "dx" since aliases are not available from here
            // see BACKLOG-10563
            command = command.replace("dx:", "jahia:");
        }

        return execute(command, timeout, silent, principals);
    }

    private String execute(final String command, final Long timeout, final Boolean silent, final Principal... principals) {
        waitForCommandService(command);

        String response;
        final ByteArrayOutputStream byteArrayOutputStream = new ByteArrayOutputStream();
        final PrintStream printStream = new PrintStream(byteArrayOutputStream);
        final Session session = sessionFactory.create(System.in, printStream, System.err);

        final Callable<String> commandCallable = () -> {
            try {
                if (!silent) {
                    System.err.println(command);
                }
                Object result = session.execute(command);
                if (result != null) {
                    session.getConsole().println(result.toString());
                }
            } catch (Exception e) {
                throw new RuntimeException(e.getMessage(), e);
            }
            printStream.flush();
            return byteArrayOutputStream.toString();
        };

        FutureTask<String> commandFuture;
        if (principals.length == 0) {
            commandFuture = new FutureTask<>(commandCallable);
        } else {
            // If principals are defined, run the command callable via Subject.doAs()
            commandFuture = new FutureTask<>(() -> {
                Subject subject = new Subject();
                subject.getPrincipals().addAll(Arrays.asList(principals));
                return Subject.doAs(subject, (PrivilegedExceptionAction<String>) commandCallable::call);
            });
        }

        try {
            executor.submit(commandFuture);
            response = cleanupOutput(commandFuture.get(timeout, TimeUnit.MILLISECONDS));
        } catch (TimeoutException e) {
            logger.warn("Shell command has timed out: {}", command);
            throw new RuntimeException("Shell command has timed out: " + command, e);
        } catch (ExecutionException e) {
            Throwable cause = e.getCause() != null ? (e.getCause().getCause() != null ? e.getCause().getCause() : e.getCause()) : e;
            throw new RuntimeException(cause.getMessage(), cause);
        } catch (InterruptedException e) {
            throw new RuntimeException(e.getMessage(), e);
        }
        return response;
    }

}

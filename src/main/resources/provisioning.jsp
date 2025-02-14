<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ page import="org.jahia.osgi.BundleUtils" %>
<%@ page import="org.jahia.services.provisioning.ProvisioningManager" %>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
    <%@ include file="css.jspf" %>
    <title>Run provisioning script</title>
</head>
<body>
<script>
    let buttonLocked = false;
    const printMessage = () => {
        document.getElementById("provisioningMessage").setAttribute("hidden", "true");
        document.getElementById("provisioningResult").setAttribute("hidden", "true");
        buttonLocked = true;
        const provisioning = document.getElementById("provisioning").value;

        const query = new XMLHttpRequest();
         query.onreadystatechange = () => {
            if(query.readyState === XMLHttpRequest.OPENED) {
                document.getElementById("submitYaml").disabled = true;
                document.getElementById("provisioningMessage").removeAttribute("hidden");
            }
            if (query.readyState === XMLHttpRequest.DONE) {
                buttonLocked = false;
                document.getElementById("submitYaml").disabled = false;
                document.getElementById("provisioningMessage").setAttribute("hidden", "true");
                if(query.status === 200) {
                    document.getElementById("provisioningResult").innerText = "Provisioning script executed successfully, check server logs for more information";
                } else {
                    document.getElementById("provisioningResult").innerText = "Provisioning script failed, check server logs for more information";
                }
                document.getElementById("provisioningResult").removeAttribute("hidden");
            }
        }
        query.open("POST", window.location.href, true);
        console.log('printMessage');
        query.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
        const encodedProvisioning = encodeURIComponent(provisioning);
        query.send('script=' + encodedProvisioning);

    }

    const validateYaml = event => {
        if(buttonLocked) return;
        const val = document.getElementById("provisioning").value;
        if(!/^\s*[\w.-]+:\s*(.*)?$/m.test(val)) {
            document.getElementById('submitYaml').disabled = true;
            document.getElementById("submitYaml").setAttribute("title", "Invalid YAML");
        } else {
            document.getElementById('submitYaml').disabled = false;
            document.getElementById("submitYaml").removeAttribute("title");
        }
    }
    document.addEventListener("keyup", validateYaml);
</script>
<%@ include file="logout.jspf" %>
<h1>Run provisioning script</h1>
<a target="_blank" href="https://academy.jahia.com/documentation/jahia-cms/jahia-8.2/dev-ops/provisioning/creating-a-provisioning-script">Link to academy</a>
<p>Paste here the provisioning script you would like to execute against Jahia:</p>
<form method="post" id="provisioningForm">
    <textarea name="script" id="provisioning" style="width: 100%; height: 500px;" required></textarea>
    <button id="submitYaml" type="button" onclick="printMessage()" disabled> Run provisioning script </button>
</form>

<h2 hidden="true" id="provisioningMessage"><strong>Request sent, waiting for provisioning API response</strong></h2>
<strong><h2 hidden=true id="provisioningResult"></h2></strong>
<c:if test="${not empty param.script}">
<h2><strong>Request sent, check the logs for the result</strong></h2>
    <%
        ProvisioningManager provisioningManager = (ProvisioningManager) BundleUtils.getOsgiService("org.jahia.services.provisioning.ProvisioningManager", null);
        provisioningManager.executeScript(request.getParameter("script"), "yaml");
    %>
</c:if>
</body>
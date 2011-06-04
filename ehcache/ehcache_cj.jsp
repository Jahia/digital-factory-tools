<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ page import="net.sf.ehcache.Ehcache" %>
<%@ page import="net.sf.ehcache.Statistics" %>
<%@ page import="org.jahia.services.render.filter.cache.ModuleCacheProvider" %>
<%@ page import="java.util.Collections" %>
<%@ page import="java.util.Set" %>
<%@ page import="org.jahia.services.cache.CacheEntry" %>
<%@ page import="net.sf.ehcache.Element" %>
<%@ page import="java.util.List" %>
<%@ page import="java.text.SimpleDateFormat" %>
<%@ page import="java.util.Date" %>
<%@ page import="org.apache.commons.io.FileUtils" %>
<%@ page import="org.jahia.services.render.filter.cache.DefaultCacheKeyGenerator" %>
<%--
  Output cache monitoring JSP.
  User: rincevent
  Date: 28 mai 2008
  Time: 16:59:07
--%>
<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<c:if test="${not empty param.key}">
<html>
<body>
<%
	System.out.println(request.getParameter("key"));
    Element elem = ModuleCacheProvider.getInstance().getCache().get(request.getParameter("key"));
    Object obj = elem != null ? ((CacheEntry) elem.getValue()).getObject() : null;
%><%= obj %>
</body>
</html>
</c:if>
<c:if test="${empty param.key}">
<html>
<head>
    <link type="text/css" href="css/demo_table.css" rel="stylesheet"/>
    <script type="text/javascript" src="jquery.min.js" language="JavaScript"></script>
    <script type="text/javascript" src="jquery.dataTables.min.js" language="JavaScript"></script>
    <title>Display content of module output cache</title>
    <script type="text/javascript">
        var myTable = $(document).ready(function() {
            $('#cacheTable').dataTable({
                "bLengthChange": true,
                "bFilter": true,
                "bSort": true,
                "bInfo": false,
                "bAutoWidth": true,
                "bStateSave" : true,
                "aoColumns": [
                    null,
                    {
                        "sType": "html"
                    }
                ],
                "sPaginationType": "full_numbers"
            });
        });
    </script>
</head>
<%
	ModuleCacheProvider cacheProvider = ModuleCacheProvider.getInstance();
    Ehcache cache = cacheProvider.getCache();
	Ehcache depCache = cacheProvider.getDependenciesCache();
    if (pageContext.getRequest().getParameter("flush") != null) {
        System.out.println("Flushing cache content");
        cache.flush();
        cache.clearStatistics();
        cache.removeAll();
        depCache.flush();
        depCache.clearStatistics();
        depCache.removeAll();
        ((DefaultCacheKeyGenerator)cacheProvider.getKeyGenerator()).flushUsersGroupsKey();
    }
    List keys = cache.getKeys();
    Collections.sort(keys);
    pageContext.setAttribute("keys", keys);
    pageContext.setAttribute("cache", cache);
    pageContext.setAttribute("stats", cache.getStatistics());
%>
<body style="background-color: white;">
<a href="index.html" title="back to the overview of caches">overview</a>&nbsp;
<a href="?refresh">refresh</a>&nbsp;
<a href="?flush=true" onclick="return confirm('This will flush the content of the cache. Would you like to continue?')" title="flush the content of the module output cache">flush</a>&nbsp;
<a href="?viewContent=${param.viewContent ? 'false' : 'true'}">${param.viewContent ? 'hide content preview' : 'preview content'}</a>
<div id="statistics">
    <span>Cache Hits: ${stats.cacheHits} (Cache hits in memory : ${stats.inMemoryHits}; Cache hits on disk : ${stats.onDiskHits})</span><br/>
    <span>Cache Miss: ${stats.cacheMisses}</span><br/>
    <span>Object counts: ${stats.objectCount}</span><br/>
    <span>Memory size: ${cache.memoryStoreSize}</span><br/>
    <span>Disk size: ${cache.diskStoreSize}</span><br/>
    <span>Cache entries size = <span id="cacheSize"></span></span><br/>
    <span>Dependencies cache entries size = <span id="depsCacheSize"></span></span><br/>
</div>
<div id="keys">
    <table id="cacheTable">
        <thead>
        <tr>
            <th>Key</th>
            <th>Expiration</th>
            <th>Value</th>
            <th>Dependencies</th>
        </tr>
        </thead>
        <tbody>
        <% long cacheSize = 0; %>
        <% long globalDepsCacheSize = 0; %>
        <c:forEach items="${keys}" var="key" varStatus="i">

            <tr>
                    <% String attribute = (String) pageContext.getAttribute("key");
                        final Element element1 = cache.getQuiet(attribute);
                        if (element1 != null) {
                    %>

                <td>${key}</td>
                <td><%=SimpleDateFormat.getDateTimeInstance().format(new Date(element1.getExpirationTime()))%></td>
                <% String content = (String)((CacheEntry)element1.getValue()).getObject();
                cacheSize += content != null ? content.length() : 0;
                %>
                <td>
                	<c:if test="${param.viewContent}" var="viewContent">
                		<%= content %>
                	</c:if>
                	<c:if test="${not viewContent}">
                		<center>
                		<c:url var="detailsUrl" value="ehcache_cj.jsp">
                			<c:param name="key" value="${key}"/>
                		</c:url>
                		<a href="${detailsUrl}" target="_blank">view</a>
                		<br/>[<%= FileUtils.byteCountToDisplaySize(content.length()).replace(" ","&nbsp;") %>]
                		</center>
                	</c:if>
                </td>
                <td><%
                    Element element = depCache.getQuiet(cacheProvider.getKeyGenerator().getPath(attribute));
                    if(element !=null) {
                        Set<String> deps = (Set<String>) element.getValue();
                        long depsCacheSize = 0;
                        for (String dep : deps) {
                            depsCacheSize += dep.length();
                            out.print(dep+"<br/>");
                        }%>
                    <br/>[<%= FileUtils.byteCountToDisplaySize(content.length()).replace(" ","&nbsp;") %>]
                    <%
                        globalDepsCacheSize += depsCacheSize;
                    }
                %></td>
                <%}%>
            </tr>
        </c:forEach>
	    <script type="text/javascript">
		    $(document).ready(function() {
		        $("#cacheSize").before("<%= FileUtils.byteCountToDisplaySize(cacheSize) %>");
                $("#depsCacheSize").before("<%= FileUtils.byteCountToDisplaySize(globalDepsCacheSize) %>");
	        });
	    </script>
        </tbody>
    </table>
</div>
<a href="index.html">overview</a>
</body>
</html>
</c:if>
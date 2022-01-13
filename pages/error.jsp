<%@page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%@page import="java.net.URLDecoder" %>
<%@page import="java.io.*"%>
<%@page import="org.json.simple.*"%>
<%@page import="org.json.simple.parser.*"%>
<%@page import="org.json.simple.JSONObject"%>
<%@page import="org.json.simple.JSONArray"%>
<%@page import="java.util.Calendar"%>
<%@page import="java.text.DecimalFormat"%>

<%
session.setMaxInactiveInterval(2);
%>

 <script type="text/javascript">
var Msg ='<%=session.getAttribute("error message")%>';
    console.log(Msg);
    if (Msg != "null") {
        
    function alertName(){
    alert(Msg);
    } 
 }
 </script> 


<script type="text/javascript"> window.onload = alertName; </script>
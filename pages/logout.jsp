<%@page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@page import="java.io.*"%>
<%

    session.invalidate();
    response.sendRedirect("login.jsp");
%>
 
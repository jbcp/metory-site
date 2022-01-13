<%@page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%
  response.sendRedirect(request.getContextPath()+"/pages/"); 
  //   response.sendRedirect(request.getRequestURL().replace(0,4,"https")+"pages/");
%>

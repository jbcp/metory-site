<%@page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@page import="java.io.*"%>
<%
     String session_info;
     session_info = session.getAttribute("READROLE") + "_"
                    + session.getAttribute("CREATEROLE") + "_"
                    + session.getAttribute("MODIFYROLE") + "_"
                    + session.getAttribute("RESERVEROLE") + "_"                
                    + session.getAttribute("IDENTITYROLE")+ "_"
                    + session.getAttribute("CONSENTROLE")+ "_"
                    + session.getAttribute("SIGNROLE")+ "_"
                    + session.getAttribute("ADMINROLE")+ "_"
                    + session.getAttribute("BCADMINROLE")+ "_"
                    + session.getAttribute("STUDYADMINROLE")+ "_"
                    + session.getAttribute("SITEID")+ "_"
                    + session.getAttribute("SITENAME")+ "_"
                    + session.getAttribute("INVNAME");
                   
     out.println(session_info);


     /*              session.setAttribute("INVID", rs.getInt(2));
                    session.setAttribute("SITEID", rs.getInt(3));
                    session.setAttribute("SITENAME", rs.getString(4));
                    session.setAttribute("INVNAME", rs.getString(5)); 
                    session.setAttribute("INVMAIL", rs.getString(6)); 
                    session.setAttribute("READROLE", rs.getInt(7)); // who can read a study info
                    session.setAttribute("CREATEROLE", rs.getInt(8)); // who can create a study info.
                    session.setAttribute("MODIFYROLE", rs.getInt(9)); // who can modify the study information
                    session.setAttribute("RESERVEROLE", rs.getInt(10)); // who can make a reservation for an applicant
                    session.setAttribute("IDENTITYROLE", rs.getInt(11)); // who can check the identification of an applicant is the same on the db
                    session.setAttribute("CONSENTROLE", rs.getInt(12)); // who can view consent process
                    session.setAttribute("SIGNROLE", rs.getInt(13));  // who can sign on a consent and submit the signed consent to block chain
                    session.setAttribute("ADMINROLE", rs.getInt(14)); //org admin role: can add a member
                    session.setAttribute("BCADMINROLE", rs.getInt(15)); //블록체인 관리자
                    session.setAttribute("STUDYADMINROLE", rs.getInt(16)); //모든 연구를 보고 수정 하는 연구admin        
                    */
%>
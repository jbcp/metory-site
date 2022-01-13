<%@page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%@page import="java.net.URLDecoder" %>
<%@page import="java.io.*"%>
<%@page import="org.json.simple.*"%>
<%@page import="org.json.simple.parser.*"%>
<%@page import="org.json.simple.JSONObject"%>
<%@page import="org.json.simple.JSONArray"%>
<%
 
    JSONParser db_parser = new JSONParser();
    Object obj = db_parser.parse(new FileReader("../config/dbconfig.json"));
    JSONObject jo = (JSONObject) obj;   
    String jdbcDriverValue = (String)jo.get("host");
    String dbId = (String)jo.get("username");
    String dbPass = (String)jo.get("password");
    
    Class.forName("com.mysql.jdbc.Driver");
    String jdbcDriver = jdbcDriverValue;
    Connection conn= DriverManager.getConnection(jdbcDriver,dbId, dbPass); 
    Statement stmt =null;
    stmt = conn.createStatement();

    try{
        String id = request.getParameter("id");
        String redirectURL = "./";
        int count_id = 0;

        String query = "select count(I.INVID) from INVESTIGATOR I where I.INVMAIL = '"+id+"'";
        ResultSet rs = stmt.executeQuery(query);

        while(rs.next()){
            count_id = rs.getInt(1);
        }
        stmt.close();
        conn.close();
        out.print(count_id);
    }catch(Exception e){
        e.printStackTrace();
        out.println(e.toString());
    }
    finally{
         if(stmt!=null) { try{stmt.close();} catch(Exception e){}}  stmt.close();
         if(conn!=null) { try{conn.close();} catch(Exception e){}}  conn.close();
    }
%>

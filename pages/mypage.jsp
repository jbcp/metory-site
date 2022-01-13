
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
<%@page import="java.util.*"%>
<%@page import="java.sql.SQLException"%>
<%!
    String selectPreviousInformation(Statement _stmt, String _logTableName, String _tableName, String _tableSchemaName) throws SQLException {
        List<String> logcolumnNames = new ArrayList();
        String selectlogColumnNameQuery="SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='"+_tableSchemaName+"' AND TABLE_NAME='"+_logTableName+"' AND COLUMN_KEY != 'PRI'";
        ResultSet rs = _stmt.executeQuery(selectlogColumnNameQuery);
        while(rs.next()){
            logcolumnNames.add(rs.getString(1));
        }        
        String selectlogColumn = "("+String.join(",",logcolumnNames)+")";
        
        // query 변수의 현재까지의 value => insert into [logtablename](col1,...,coln)
        String query = "insert into "+_logTableName+selectlogColumn;

        List<String> columnNames = new ArrayList();
        String selectColumnNameQuery="SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='"+_tableSchemaName+"' AND TABLE_NAME='"+_tableName+"'";
        rs = _stmt.executeQuery(selectColumnNameQuery);
        while(rs.next()){
            columnNames.add(rs.getString(1));
        }

        // query 변수의 현재까지의 value => insert into [logtablename](col1,...,coln) select [col1,...,col(n-4)] // n-4인 이유는, 로그테이블칼럼이 4개이므로(WHO,WHO_ID,HOW,LOGDTC)
        query = query + " select " + String.join(",",columnNames);
        return query;
    }

    int getLastInsertID(Statement _stmt) throws SQLException {
        ResultSet rs = _stmt.executeQuery("SELECT LAST_INSERT_ID()");
        int id=0;
        while(rs.next()){
            id = rs.getInt(1);
        }

        return id;
    }
%>

<%
 
    JSONParser db_parser = new JSONParser();
    Object obj = db_parser.parse(new FileReader("../config/dbconfig.json"));
    JSONObject jo = (JSONObject) obj;
    
    String jdbcDriverValue = (String)jo.get("host");
    String dbId = (String)jo.get("username");
    String dbPass = (String)jo.get("password");
    String tableSchemaName = jdbcDriverValue.split("/")[jdbcDriverValue.split("/").length-1].split("\\?")[0];
    
 
    Class.forName("com.mysql.jdbc.Driver");
    String jdbcDriver = jdbcDriverValue;
    Connection conn= DriverManager.getConnection(jdbcDriver,dbId, dbPass); 
    Statement stmt =null;
    stmt = conn.createStatement();
    int SITEID = (int)session.getAttribute("SITEID");
   int INVID = (int)session.getAttribute("INVID");

try{
    String type = request.getParameter("action");

    if(type.equals("load_detail")){

      
        String query = "SELECT * FROM INVESTIGATOR WHERE INVID = "+INVID;
        ResultSet rs = stmt.executeQuery(query);

        JSONArray members = new JSONArray();

        while(rs.next()){
            JSONObject member = new JSONObject();
            member.put("INVID", rs.getInt(1));
            member.put("INVNAME", rs.getString(3));
            member.put("INVMAIL", rs.getString(4));
            member.put("INVCELLPHONENUM", rs.getString(6));
            member.put("ROLEID", rs.getInt(7));
            member.put("INVPHONENUM", rs.getString(8));
            member.put("INVDEPARTMENT", rs.getString(9));
            member.put("INVPOSITION", rs.getString(10));
            member.put("INVOFFICE", rs.getString(11));
            members.add(member);
        }

        stmt.close();
        conn.close();
        out.println(members);
    }

    else if(type.equals("modify_mypage")){
        String INVID_INPUT = request.getParameter("INVID");     

        String INVPASSWORD = request.getParameter("INVPASSWORD");
        String INVPASS = URLDecoder.decode(request.getParameter("INVPASSWORD"), "UTF-8");
        String INVOFFICE = URLDecoder.decode(request.getParameter("INVOFFICE"), "UTF-8");
        String INVCELLPHONENUM =URLDecoder.decode(request.getParameter("INVCELLPHONENUM"), "UTF-8");
        String INVPHONENUM = URLDecoder.decode(request.getParameter("INVPHONENUM"), "UTF-8");
        String INVPOSITION = URLDecoder.decode(request.getParameter("INVPOSITION"), "UTF-8");
        String INVDEPARTMENT = URLDecoder.decode(request.getParameter("INVDEPARTMENT"), "UTF-8");

        String query = "";

      
         if(INVPASSWORD==null || INVPASSWORD=="")
            query = "UPDATE INVESTIGATOR SET INVOFFICE= '"+INVOFFICE+"', INVCELLPHONENUM = '"+INVCELLPHONENUM+"', INVPHONENUM = '"+INVPHONENUM+"', INVDEPARTMENT='"+INVDEPARTMENT+"', INVPOSITION='"+INVPOSITION+"'  WHERE INVID = "+INVID_INPUT;
        else
            query = "UPDATE INVESTIGATOR SET INVPWD = '"+INVPASS+"', INVOFFICE= '"+INVOFFICE+"', INVCELLPHONENUM = '"+INVCELLPHONENUM+"', INVPHONENUM = '"+INVPHONENUM+"' WHERE INVID = "+INVID_INPUT;
        stmt.executeUpdate(query);

        // INVESTIGATOR_LOG 저장 - UPDATE
        String prevQuery = selectPreviousInformation(stmt, "INVESTIGATOR_LOG", "INVESTIGATOR", tableSchemaName);
        String logInsertQuery = prevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from INVESTIGATOR where INVID="+INVID_INPUT;
        stmt.executeUpdate(logInsertQuery);

        stmt.close();
        conn.close();
    }

    else if(type.equals("check_password")){
        String INVID_INPUT = request.getParameter("INVID");
       
        String INVPASS = URLDecoder.decode(request.getParameter("INVPASSWORD"), "UTF-8");
        String responses = "false";

        String query = "SELECT INVPWD FROM INVESTIGATOR where INVID = "+INVID_INPUT;
        ResultSet rs = stmt.executeQuery(query);

        while(rs.next()){
            if(INVPASS.equals(rs.getString(1))){
                responses = "true";
            }
        }
        stmt.close();
        conn.close();
        out.print(responses);
    }
    else{
        stmt.close();
        conn.close();
    }
      }catch(Exception e){
   
        e.printStackTrace();
        out.println(e.toString());
    }
    finally{
         if(stmt!=null) { try{stmt.close();} catch(Exception e){}}  stmt.close();
         if(conn!=null) { try{conn.close();} catch(Exception e){}}  conn.close();
    }
%>

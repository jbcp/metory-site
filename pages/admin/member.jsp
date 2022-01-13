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
<%@page import="java.security.*" %>

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
    String INVNAME = session.getAttribute("INVNAME").toString();
    String SITENAME = session.getAttribute("SITENAME").toString();

    try{
        String type = request.getParameter("action");

        if(type.equals("load")){
          
            String query = "SELECT * FROM INVESTIGATOR WHERE SITEID = "+SITEID;
            ResultSet rs = stmt.executeQuery(query);

            JSONArray members = new JSONArray();

            while(rs.next()){
                JSONObject member = new JSONObject();
                member.put("INVID", rs.getInt("INVID"));
                member.put("INVNAME", rs.getString("INVNAME"));
                member.put("INVMAIL", rs.getString("INVMAIL"));
                member.put("INVCELLPHONENUM", rs.getString("INVCELLPHONENUM"));
                member.put("ROLEID", rs.getInt("ROLEID"));
                member.put("INVPHONENUM", rs.getString("INVPHONENUM"));
                member.put("INVDEPARTMENT", rs.getString("INVDEPARTMENT"));
                member.put("INVPOSITION", rs.getString("INVPOSITION"));
                member.put("INVOFFICE", rs.getString("INVOFFICE"));
                 member.put("ACTIVE", rs.getInt("ACTIVE"));
                members.add(member);
            }

            stmt.close();
            conn.close();
            out.println(members);
        }

        else if(type.equals("load_detail")){

          
            String query = "SELECT * FROM INVESTIGATOR WHERE INVID = "+INVID;
            ResultSet rs = stmt.executeQuery(query);

            JSONArray members = new JSONArray();

            while(rs.next()){
                JSONObject member = new JSONObject();
                member.put("INVID", rs.getInt("INVID"));
                member.put("INVNAME", rs.getString("INVNAME"));
                member.put("INVMAIL", rs.getString("INVMAIL"));
                member.put("INVCELLPHONENUM", rs.getString("INVCELLPHONENUM"));
                member.put("ROLEID", rs.getInt("ROLEID"));
                member.put("INVPHONENUM", rs.getString("INVPHONENUM"));
                member.put("INVDEPARTMENT", rs.getString("INVDEPARTMENT"));
                member.put("INVPOSITION", rs.getString("INVPOSITION"));
                member.put("INVOFFICE", rs.getString("INVOFFICE"));

                members.add(member);
            }

            stmt.close();
            conn.close();
            out.println(members);
        }

        else if(type.equals("load_detail_admin")){
            String INVID_INPUT = request.getParameter("INVID");
            String query = "SELECT * FROM INVESTIGATOR WHERE INVID = "+INVID_INPUT;
            ResultSet rs = stmt.executeQuery(query);

            JSONArray members = new JSONArray();

            while(rs.next()){
                JSONObject member = new JSONObject();
                member.put("INVID", rs.getInt("INVID"));
                member.put("INVNAME", rs.getString("INVNAME"));
                member.put("INVMAIL", rs.getString("INVMAIL"));
                member.put("INVCELLPHONENUM", rs.getString("INVCELLPHONENUM"));
                member.put("ROLEID", rs.getInt("ROLEID"));
                member.put("DOCTOR", rs.getInt("DOCTOR"));               
                member.put("INVPHONENUM", rs.getString("INVPHONENUM"));
                member.put("INVDEPARTMENT", rs.getString("INVDEPARTMENT"));
                member.put("INVPOSITION", rs.getString("INVPOSITION"));
                member.put("INVOFFICE", rs.getString("INVOFFICE"));
                member.put("ACTIVE", rs.getString("ACTIVE"));
                members.add(member);
            }

            stmt.close();
            conn.close();
            out.println(members);
        }

        else if(type.equals("modify_mypage")){
           
            String INVPASS = request.getParameter("INVPASSWORD");
            String INVOFFICE = URLDecoder.decode(request.getParameter("INVOFFICE"), "UTF-8");
            String INVCELLPHONENUM = request.getParameter("INVCELLPHONENUM");
            String INVPHONENUM = request.getParameter("INVPHONENUM");

            String query = "";

            if(INVPASS.equals(""))
                query = "UPDATE INVESTIGATOR SET INVOFFICE= '"+INVOFFICE+"', INVCELLPHONENUM = '"+INVCELLPHONENUM+"', INVPHONENUM = '"+INVPHONENUM+"' WHERE INVID = "+INVID;
            else
                query = "UPDATE INVESTIGATOR SET INVPWD = '"+INVPASS+"', INVOFFICE= '"+INVOFFICE+"', INVCELLPHONENUM = '"+INVCELLPHONENUM+"', INVPHONENUM = '"+INVPHONENUM+"' WHERE INVID = "+INVID;
            
            log("[METORY log]"+"\t||\t[SITEID]="+SITEID+"\t||\t[INVID]="+INVID+"\t||\t[type]="+type+"\t||\t[QUERY]="+query.replace("'", "\'"));        
            stmt.executeUpdate(query);

            stmt.close();
            conn.close();
        }
        
        else if(type.equals("change_role")){
            String INVID_INPUT = request.getParameter("INVID");
            String ROLEID = request.getParameter("status");
            
            String query = "UPDATE INVESTIGATOR SET ROLEID = " + ROLEID + " WHERE INVID = "+INVID_INPUT;
            stmt.executeUpdate(query);

            // INVESTIGATOR_LOG 저장 - UPDATE
            String prevQuery = selectPreviousInformation(stmt, "INVESTIGATOR_LOG", "INVESTIGATOR", tableSchemaName);
            String logInsertQuery = prevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from INVESTIGATOR where INVID="+INVID_INPUT;
            stmt.executeUpdate(logInsertQuery);


            stmt.close();
            conn.close();
        }

        else if(type.equals("modify_inv")){
            String INVID_INPUT = request.getParameter("INVID");
            String INVNAME_INPUT = request.getParameter("INVNAME");
            String INVDEPARTMENT = request.getParameter("INVDEPARTMENT");
            String INVPOSITION = request.getParameter("INVPOSITION");
            String INVOFFICE = request.getParameter("INVOFFICE");
            String INVMAIL = request.getParameter("INVMAIL");
            String INVCELLPHONE = request.getParameter("INVCELLPHONE");
            String INVPHONE = request.getParameter("INVPHONE");
            String DOCTOR = request.getParameter("DOCTOR");
            String ACTIVE = request.getParameter("ACTIVE");
            String ACTIVEDATE = request.getParameter("ACTIVEDATE");
            String INACTIVEDATE = request.getParameter("INACTIVEDATE");
            String ADD_DATE_STRING="";
            if(ACTIVE.equals("1") && !ACTIVEDATE.equals("")) ADD_DATE_STRING=" , ACTIVEDATE= '"+ ACTIVEDATE+"'";
            if(ACTIVE.equals("0") && !INACTIVEDATE.equals("")) ADD_DATE_STRING=" , INACTIVEDATE='"+ INACTIVEDATE+"'";

            String query = "UPDATE INVESTIGATOR SET DOCTOR="+DOCTOR+", INVNAME = '"+INVNAME_INPUT+"', INVMAIL = '"+INVMAIL+"', INVCELLPHONENUM = '"+INVCELLPHONE+"', INVDEPARTMENT = '"+INVDEPARTMENT+"', INVPOSITION = '"+INVPOSITION+"', INVOFFICE = '"+INVOFFICE+"', INVPHONENUM = '"+INVPHONE+ "', ACTIVE="+ACTIVE+ADD_DATE_STRING+"  WHERE INVID = "+INVID_INPUT;
            stmt.executeUpdate(query);

            // INVESTIGATOR_LOG 저장 - UPDATE
            String prevQuery = selectPreviousInformation(stmt, "INVESTIGATOR_LOG", "INVESTIGATOR", tableSchemaName);
            String logInsertQuery = prevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from INVESTIGATOR where INVID="+INVID_INPUT;
            stmt.executeUpdate(logInsertQuery);

            stmt.close();
            conn.close();
            out.print(INVNAME);
        }

        else if(type.equals("add_inv")){
           
            String INVNAME_INPUT = request.getParameter("INVNAME");
            String INVDEPARTMENT = request.getParameter("INVDEPARTMENT");
            String INVPOSITION = request.getParameter("INVPOSITION");
            String INVOFFICE = request.getParameter("INVOFFICE");
            String INVMAIL = request.getParameter("INVMAIL");
            String INVCELLPHONE = request.getParameter("INVCELLPHONE");
            String INVPHONE = request.getParameter("INVPHONE");
            String ROLEID = request.getParameter("ROLEID");
            String DOCTOR = request.getParameter("DOCTOR");
            String ACTIVE = request.getParameter("ACTIVE");

            String INVPWD = URLDecoder.decode(request.getParameter("INVPWD"), "UTF-8");
            String query ="";
            if(ACTIVE.equals("1")){
                DecimalFormat df = new DecimalFormat("00");
                Calendar calendar = Calendar.getInstance();

                String year = Integer.toString(calendar.get(Calendar.YEAR)); 
                String month = df.format(calendar.get(Calendar.MONTH) + 1); 
                String day = df.format(calendar.get(Calendar.DATE)); 
                
                String today = year+"-"+month+"-"+day;
                query = "INSERT INTO INVESTIGATOR(SITEID, INVNAME, INVMAIL, INVPWD, INVCELLPHONENUM, ROLEID, INVPHONENUM, INVDEPARTMENT, INVPOSITION, INVOFFICE, DOCTOR, ACTIVE, ACTIVEDATE) VALUES("+SITEID+", '"+INVNAME_INPUT+"', '"+INVMAIL+"', '"+INVPWD+"', '"+INVCELLPHONE+"', "+ROLEID+", '"+INVPHONE+"', '"+INVDEPARTMENT+"', '"+INVPOSITION+"', '"+INVOFFICE+"',"+DOCTOR+","+ACTIVE+",'"+today+"');";
                
            }
            else {
                query = "INSERT INTO INVESTIGATOR(SITEID, INVNAME, INVMAIL, INVPWD, INVCELLPHONENUM, ROLEID, INVPHONENUM, INVDEPARTMENT, INVPOSITION, INVOFFICE, DOCTOR, ACTIVE) VALUES("+SITEID+", '"+INVNAME_INPUT+"', '"+INVMAIL+"', '"+INVPWD+"', '"+INVCELLPHONE+"', "+ROLEID+", '"+INVPHONE+"', '"+INVDEPARTMENT+"', '"+INVPOSITION+"', '"+INVOFFICE+"',"+DOCTOR+","+ACTIVE+");";
                
            }
            stmt.executeUpdate(query);
            int addedINVID = getLastInsertID(stmt);

            // INVESTIGATOR_LOG 저장 - CREATE
            String prevQuery = selectPreviousInformation(stmt, "INVESTIGATOR_LOG", "INVESTIGATOR", tableSchemaName);
            String logInsertQuery = prevQuery+",'SITE', "+INVID+",'CREATE',NOW() from INVESTIGATOR where INVID="+addedINVID;
            stmt.executeUpdate(logInsertQuery);

            stmt.close();
            conn.close();
            out.print(INVNAME_INPUT);
        }

        else if(type.equals("check_password")){
            String INVID_INPUT = request.getParameter("INVID");
            String INVPASS = request.getParameter("INVPASSWORD");
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

        else if(type.equals("load_role")){
           
            String query = "SELECT * FROM ROLE WHERE SITEID = "+SITEID;
            ResultSet rs = stmt.executeQuery(query);

            JSONArray roles = new JSONArray();

            while(rs.next()){
                JSONObject role = new JSONObject();
                role.put("ROLEID", rs.getInt(1));
                role.put("ROLETITLE", rs.getString(3));
                role.put("READ", rs.getInt(4));
                role.put("CREATE", rs.getInt(5));
                role.put("MODIFY", rs.getInt(6));
                role.put("RESERVE", rs.getInt(7));
                role.put("IDENTITY", rs.getInt(8));
                role.put("CONSENT", rs.getInt(9));
                role.put("SIGN", rs.getInt(10));
                role.put("ADMIN", rs.getInt(11));
                role.put("BCADMIN", rs.getInt(12));
                role.put("STUDYADMIN", rs.getInt(13));
               //role.put("ROLECODE", rs.getInt(14));
                roles.add(role);
            }

            stmt.close();
            conn.close();
            out.println(roles);
        }

        else if(type.equals("add_role")){
           
            String ROLETITLE = request.getParameter("ROLETITLE");
            String READ = request.getParameter("READ");
            String CREATE = request.getParameter("CREATE");
            String MODIFY = request.getParameter("MODIFY");
            String RESERVE = request.getParameter("RESERVE");
            String IDENTITY = request.getParameter("IDENTITY");
            String CONSENT = request.getParameter("CONSENT");
            String SIGN = request.getParameter("SIGN");
            String ADMIN = request.getParameter("ADMIN");
            String BCADMIN = request.getParameter("BCADMIN");
            String STUDYADMIN = request.getParameter("STUDYADMIN");

            String query = "INSERT INTO ROLE(SITEID, ROLETITLE, READROLE, CREATEROLE, MODIFYROLE, RESERVEROLE, IDENTITYROLE, CONSENTROLE, SIGNROLE, ADMINROLE,  BCADMINROLE, STUDYADMINROLE) VALUES("+SITEID+", '"+ROLETITLE+"', "+READ+", "+CREATE+", "+MODIFY+", "+RESERVE+", "+IDENTITY+", "+CONSENT+", "+SIGN+", "+ADMIN+", "+BCADMIN+", "+STUDYADMIN+");";
            stmt.executeUpdate(query);
            int ROLEID = getLastInsertID(stmt);

            // ROLE_LOG 저장 - CREATE
            String prevQuery = selectPreviousInformation(stmt, "ROLE_LOG", "ROLE", tableSchemaName);
            String logInsertQuery = prevQuery+",'SITE', "+INVID+",'CREATE',NOW() from ROLE where ROLEID="+ROLEID;
            stmt.executeUpdate(logInsertQuery);

            stmt.close();
            conn.close();
        }

        else if(type.equals("load_detail_role")){
            String ROLEID = request.getParameter("ROLEID");

            String query = "SELECT ROLEID,ROLETITLE,READROLE,CREATEROLE,MODIFYROLE,RESERVEROLE,IDENTITYROLE,CONSENTROLE,SIGNROLE,ADMINROLE,BCADMINROLE,STUDYADMINROLE   FROM ROLE WHERE ROLEID = "+ROLEID;
            ResultSet rs = stmt.executeQuery(query);

            JSONArray roles = new JSONArray();

            while(rs.next()){
                JSONObject role = new JSONObject();
                role.put("ROLEID", rs.getInt(1));
                role.put("ROLETITLE", rs.getString(2));
                role.put("READ", rs.getInt(3));
                role.put("CREATE", rs.getInt(4));
                role.put("MODIFY", rs.getInt(5));
                role.put("RESERVE", rs.getInt(6));
                role.put("IDENTITY", rs.getInt(7));
                role.put("CONSENT", rs.getInt(8));
                role.put("SIGN", rs.getInt(9));
                role.put("ADMIN", rs.getInt(10));
                role.put("BCADMIN", rs.getInt(11));
                 role.put("STUDYADMIN", rs.getInt(12));
                //  role.put("ROLECODE", rs.getInt(13));
                roles.add(role);
            }

            stmt.close();
            conn.close();
            out.println(roles);
        }

        else if(type.equals("modify_role")){
            String ROLEID = request.getParameter("ROLEID");
            String ROLETITLE = request.getParameter("ROLETITLE");
            String READ = request.getParameter("READ");
            String CREATE = request.getParameter("CREATE");
            String MODIFY = request.getParameter("MODIFY");
            String RESERVE = request.getParameter("RESERVE");
            String IDENTITY = request.getParameter("IDENTITY");
            String CONSENT = request.getParameter("CONSENT");
            String SIGN = request.getParameter("SIGN");
            String ADMIN = request.getParameter("ADMIN");
            String BCADMIN = request.getParameter("BCADMIN");
            String STUDYADMIN = request.getParameter("STUDYADMIN");
            String query = "UPDATE ROLE SET ROLETITLE = '"+ROLETITLE+"', READROLE="+READ+", CREATEROLE="+CREATE+", MODIFYROLE="+MODIFY+", RESERVEROLE="+RESERVE+", IDENTITYROLE="+IDENTITY+", CONSENTROLE="+CONSENT+", SIGNROLE = "+SIGN+", ADMINROLE="+ADMIN+", BCADMINROLE="+BCADMIN+", STUDYADMINROLE="+STUDYADMIN+" WHERE ROLEID="+ROLEID+";";
            stmt.executeUpdate(query);
            
            // ROLE_LOG 저장 - UPDATE
            String prevQuery = selectPreviousInformation(stmt, "ROLE_LOG", "ROLE", tableSchemaName);
            String logInsertQuery = prevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from ROLE where ROLEID="+ROLEID;
            stmt.executeUpdate(logInsertQuery);

            stmt.close();
            conn.close();
        }

        else if(type.equals("delete_role")){
            String ROLEID = request.getParameter("ROLEID");
            int INVCOUNT = 0;
            String check = "SELECT COUNT(*) FROM INVESTIGATOR WHERE ROLEID = "+ROLEID+";";
            ResultSet rs = stmt.executeQuery(check);
            while(rs.next()){
                INVCOUNT = rs.getInt(1);
            }
            stmt.close();
            stmt = conn.createStatement();

            if(INVCOUNT == 0){
                String query = "DELETE FROM ROLE WHERE ROLEID="+ROLEID+";";
                stmt.executeUpdate(query);
                
                // ROLE_LOG 저장 - DELETE
                String prevQuery = selectPreviousInformation(stmt, "ROLE_LOG", "ROLE", tableSchemaName);
                String logInsertQuery = "INSERT INTO role_log(ROLEID, WHO, WHO_ID, HOW, LOGDTC) values("+ROLEID+",'SITE',"+INVID+",'DELETE',NOW())";
                stmt.executeUpdate(logInsertQuery);
            }

            stmt.close();
            conn.close();
            out.println(INVCOUNT);
        }

        else if(type.equals("reset_psw")){
            JSONParser psw_parser = new JSONParser();
            Object psw_obj = psw_parser.parse(new FileReader("../config/resetpsw.json"));
            JSONObject psw_jo = (JSONObject) psw_obj;
            
            String RESET_PSW = (String)psw_jo.get("reset_psw");

            byte[] b = RESET_PSW.getBytes();
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            md.update(b);			
			byte[] bResult = md.digest();
			StringBuffer sb = new StringBuffer();			
			for (byte data : bResult) {
				sb.append(String.format("%02x", data));
			}			
			String sha_psw = sb.toString();


            String INVID_INPUT = request.getParameter("INVID");
            String query = "UPDATE INVESTIGATOR SET INVPWD = '"+sha_psw+"' WHERE INVID = "+INVID_INPUT;
            stmt.executeUpdate(query);

            stmt.close();
            conn.close();
            out.print("\"" + RESET_PSW + "\"로 비밀번호가 초기화 되었습니다.");
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

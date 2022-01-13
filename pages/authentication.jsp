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
<%@page import="java.security.*"%>
<%
 
    JSONParser db_parser = new JSONParser();
    Object obj = db_parser.parse(new FileReader("../config/dbconfig.json"));
    JSONObject jo = (JSONObject) obj;
    
    String jdbcDriverValue = (String)jo.get("host");
    String dbId = (String)jo.get("username");
    String dbPass = (String)jo.get("password");

    Class.forName("com.mysql.jdbc.Driver");
    //String jdbcDriver = "jdbc:mysql://"+DB_info.get("ip")+":"+DB_info.get("port")+"/"+DB_info.get("dbName");
    String jdbcDriver = jdbcDriverValue;
    Connection conn= DriverManager.getConnection(jdbcDriver,dbId, dbPass); 

    String id = request.getParameter("id");
    String pw = request.getParameter("pw");
    String redirectURL = "./study/study.html";
    Statement stmt =null;
    stmt = conn.createStatement();

    try{
          MessageDigest sha = MessageDigest.getInstance("SHA-256");
            String encryptData= "";
        sha.update(pw.getBytes());
        byte[] digest = sha.digest();
        for(int i=0; i< digest.length; i++){
            String x = Integer.toHexString(digest[i]& 0xff);
            if(x.length()<2){
                encryptData +="0";
                
            }//if
            encryptData +=x;

        }//for

         pw = encryptData;
       
        //String redirectURL = "login.jsp?error=login-failed";
 
        

        String query = "select I.INVPWD, I.INVID, I.SITEID, S.SITENAME, I.INVNAME, I.INVMAIL, R.READROLE, R.CREATEROLE, R.MODIFYROLE, R.RESERVEROLE, R.IDENTITYROLE, R.CONSENTROLE, R.SIGNROLE, R.ADMINROLE, R.BCADMINROLE, IFNULL(R.STUDYADMINROLE,0) as STUDYADMINROLE, I.ACTIVE from INVESTIGATOR I, ROLE R, SITE S where I.ROLEID = R.ROLEID and I.SITEID = S.SITEID and I.INVMAIL = '"+id+"'";
        ResultSet rs = stmt.executeQuery(query);
        int count=0;
        while(rs.next()){
           count++;
            if(!pw.equals(rs.getString(1))) {
                      session.setAttribute("error message", "비밀번호가 맞지 않습니다.");//Just initialize a random variable.
                            redirectURL = "login.jsp";
            }
            else if (rs.getInt("I.ACTIVE") == 0){  // 퇴사;
                  
                   session.setAttribute("error message", "귀하는 더 이상 사이트 이용권한이 없습니다. ");//Just initialize a random variable.
                            redirectURL = "login.jsp";    
            }  
            else if (rs.getInt("I.ACTIVE") == 2){
                  // 관리자 승인전                   
                   session.setAttribute("error message", "귀하는 승인대기중입니다. 관리자에게 문의하여 주십시오.");//Just initialize a random variable.
                    redirectURL = "login.jsp";    
            }                  
            else {               
 
                //if(rs.getInt(6)==1) redirectURL = "./study/study.html";
                //else if(rs.getInt(6)==1) redirectURL = "./study/study.html";      
                   
                  //  if(rs.getInt("R.ADMINROLE") == 1) redirectURL = "./admin/admin.html";

                    session.setAttribute("INVID", rs.getInt(2));
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
                    session.setAttribute("STUDYADMINROLE", rs.getInt("STUDYADMINROLE")); //모든 연구를 보고 수정 하는 연구admin                  

                out.print("SITENAME="+rs.getString(4)+"   INVNAME="+rs.getString(5));
            }
            break; //한번만 check 하도록 확인설정
        }
        if(count==0){
             session.setAttribute("error message", "입력하신 이메일 가입정보가 없습니다.");//Just initialize a random variable.
             redirectURL = "login.jsp";
        }
        stmt.close();
        conn.close();
        response.sendRedirect(redirectURL);


    }catch(Exception e){
     e.printStackTrace();
        out.println(e.toString());
    }
    finally{
         if(stmt!=null) { try{stmt.close();} catch(Exception e){}}  stmt.close();
         if(conn!=null) { try{conn.close();} catch(Exception e){}}  conn.close();
    }
%>

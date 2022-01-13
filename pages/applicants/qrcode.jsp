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
        // out.println((String)jo.get("host"));
    
    String jdbcDriverValue = (String)jo.get("host");
    String dbId = (String)jo.get("username");
    String dbPass = (String)jo.get("password");
    String tableSchemaName = jdbcDriverValue.split("/")[jdbcDriverValue.split("/").length-1].split("\\?")[0];
    
    int SITEID = (int)session.getAttribute("SITEID");
    int INVID = (int)session.getAttribute("INVID");

 
    Class.forName("com.mysql.jdbc.Driver");
    //String jdbcDriver = "jdbc:mysql://"+DB_info.get("ip")+":"+DB_info.get("port")+"/"+DB_info.get("dbName");
    String jdbcDriver = jdbcDriverValue;
    Connection conn= DriverManager.getConnection(jdbcDriver,dbId, dbPass);   
    Statement stmt =null;
    stmt = conn.createStatement();

try{
    String type = request.getParameter("action");

    /*
    QRCODE 로 대상자 정보 조회
    input: QRCODE
    */
    if(type.equals("load_APPL_info")){

       // String CONSENTID = request.getParameter("CONSENTID");

        String SID = request.getParameter("SID");
        String QRCODE = request.getParameter("QRCODE");

        String exist_query = "select EXISTS (select * from APPLICANT where QRCODE = '" + QRCODE +"'  ) as success;";
        ResultSet exist_rs = stmt.executeQuery(exist_query);
        int exist = 0;
        while(exist_rs.next()){
            exist = exist_rs.getInt(1);
        }

       /*String check_inv_query = "select SITEID from INVESTIGATOR where INVID = " + INVID ;
        ResultSet check_inv_rs = stmt.executeQuery(check_inv_query);
        int SITEID=0;
        while(check_inv_rs.next()){
            SITEID = check_inv_rs.getInt(1);
        }>*/

        int result=0;
        if( exist!=0){
            String appl_query =  "SELECT APPLID, APPLNAME, APPLMAIL, APPLPHONENUM, APPLBRTHDTC, APPLSEX  FROM APPLICANT where QRCODE='"+QRCODE+"'";
            ResultSet appl_rs = stmt.executeQuery(appl_query);
            JSONObject applicant = new JSONObject();

            int APPLID=0;
           

          
            while(appl_rs.next()){
                applicant.put("APPLID", appl_rs.getInt(1));
                applicant.put("APPLNAME", appl_rs.getString(2));
                applicant.put("APPLMAIL", appl_rs.getString(3));
                applicant.put("APPLPHONENUM", appl_rs.getString(4));
                applicant.put("APPLBIRTH", appl_rs.getString(5));
                applicant.put("APPLSEX", appl_rs.getInt(6));
                APPLID= appl_rs.getInt(1);
              
               
            }

               //String exist_said_query = "select EXISTS (select * from STUDY_APPLICANT where APPLID = " + APPLID +" and CLOSESTAGE =0 and SITEID="+ SITEID+" order by SAID DESC LIMIT 1 ) as success;";
                //String exist_said_query = "select EXISTS ( select cs.CSID, sa.APPLID, sa.SAID, sa.STAGE from consent_subject cs, study_applicant sa where cs.SAID = sa.SAID and  cs.CONSENTID =" +CONSENTID+" and APPLID = "+APPLID+" and sa.SAACTIVE =1 order by cs.CSID desc) as success;";
                String exist_said_query = "select IFNULL(SAID, 0) from study_applicant  where  APPLID = "+APPLID+" and SAACTIVE =1 ";
                ResultSet exist_sid_rs = stmt.executeQuery(exist_said_query);
                int SAID=0;
               // int SID=0;
                while(exist_sid_rs.next()){
                      SAID = exist_sid_rs.getInt(1);
                    //   SID = exist_sid_rs.getInt(2);
                       applicant.put("SAID",SAID);
                }
           // }

            if(SAID !=0){ 
                int appoint_exist=0;
                
                String appoint_exist_query = "select EXISTS (select * from APPOINTMENT where SAID = "+SAID +"  and IDENTIFYDTC is null  ) as success;";
                ResultSet appoint_exist_rs = stmt.executeQuery(appoint_exist_query);
                
                while(appoint_exist_rs.next()){
                    appoint_exist = appoint_exist_rs.getInt(1);
                }
                
                int APPOINTID = 0;      
                         
                // 연구 신청자의 유효 예약(본인확인 안한 예약)  검색
                String exist_app_query = "select  IFNULL(APPOINTID,0) as APPOINTID from APPOINTMENT  where SAID ="+SAID + " and IDENTIFYDTC is null order by appointid desc LIMIT 1 ";
                ResultSet exist_app_query_rs = stmt.executeQuery(exist_app_query);
              
                while(exist_app_query_rs.next()){
                   if( exist_app_query_rs.getInt("COUNT")>0) APPOINTID = exist_app_query_rs.getInt(1);
                }                    

                if(APPOINTID==0){ //예약 없음.
                    applicant.put("APPOINTID", 0);
                } 
                else {                    

                    String app_query ="select APPOINTDTC FROM APPOINTMENT WHERE  APPOINTID = "+APPOINTID ; 
                    ResultSet app_rs = stmt.executeQuery(app_query);
                 
                    while(app_rs.next()){
                        applicant.put("APPOINTDTC", app_rs.getString(1));
                        applicant.put("APPOINTID", APPOINTID);
                    }                    

                }

                String study_query = "select TITLE FROM STUDY  WHERE SID = "+SID;
                ResultSet study_rs = stmt.executeQuery(study_query);
               
                while(study_rs.next()){
                                                
                   applicant.put("TITLE", study_rs.getString(1));                    
                    
                }

            }      
            
            out.println(applicant);
  
        }
        else out.println(0); // 가입 신청 요망
        stmt.close();
        conn.close();
       
    }
  /*
    input: QRCODE, SID

    자원자가 방문하여 방문확인시 QRCODE를 가지고 신원 확인 - 핸드폰 및 이름 추가
    1. 가입안된경우
    2. 참여중인 연구가 없음
    3. 참여중인 연구가 이 연구가 아님  
    4. 본인확인과 관련없이 예약이 하나도 없는 경우 
    5. 연구에 대해 예약이 있음 (항상 1개임)
        - javascript에서 오늘 예약인지 아닌지 보여준다.
        -회원가입시 신분확인을 안한 경우 또는 한번도 실시기관에서 신분확인을 안한 경우
    */
    else if(type.equals("VISIT_TODAY_SAID")){
      

       // String SID = request.getParameter("SID");      
        String SAID= request.getParameter("SAID");        
        JSONObject applicant = new JSONObject();
        int exist = 0;
        int applid=0;       
        int sid=0;

        //회원 정보 조회: APPLID, PASS 체크
        String appl_query =  "SELECT a.APPLID, a.APPLNAME, a.APPLMAIL, a.APPLPHONENUM, a.APPLBRTHDTC, a.APPLSEX , a.PASS, sa.SAACTIVE,  DATE_FORMAT(sa.SACLOSEDTC,'%Y-%m-%d %H:%i')  as SACLOSEDTC, sa.SID FROM APPLICANT a, study_applicant sa where sa.APPLID=a.APPLID and sa.SAID="+SAID;
        ResultSet appl_rs = stmt.executeQuery(appl_query);
           
       // int applid=0;
        int pass=0;
        while(appl_rs.next()){
            applicant.put("APPLID", appl_rs.getInt(1));
            applicant.put("APPLNAME", appl_rs.getString(2));
            applicant.put("APPLMAIL", appl_rs.getString(3));
            applicant.put("APPLPHONENUM", appl_rs.getString(4));
            applicant.put("APPLBIRTH", appl_rs.getString(5));
            applicant.put("APPLSEX", appl_rs.getInt(6));
            applicant.put("PASS", appl_rs.getInt("PASS"));
            applid = appl_rs.getInt(1);
            pass= appl_rs.getInt("PASS");
            applicant.put("SAACTIVE", appl_rs.getInt("sa.SAACTIVE"));
            applicant.put("SACLOSEDTC", appl_rs.getString("SACLOSEDTC"));
            sid=appl_rs.getInt("sa.SID");
        }

       
     
            int appoint_exist=0;                
            String appoint_exist_query = "select EXISTS (select * from APPOINTMENT where SAID = "+SAID +"  ) as success;";
            ResultSet appoint_exist_rs = stmt.executeQuery(appoint_exist_query);
                
            while(appoint_exist_rs.next()){
                appoint_exist = appoint_exist_rs.getInt(1);
            }
            
            if(appoint_exist==0)    {//4. 본인확인과 관련없이 예약이 하나도 없는 경우
                applicant.put("RESULT","error");
                applicant.put("MSG","예약없음");
                applicant.put("SAID",SAID);  
                                    
                applicant.put("APPOINTID",0);             
                

            }
            else{ // 5.연구에 대해 예약이 있음 (항상 1개임. javascript에서 오늘 예약인지 아닌지 보여준다.)
         
                String exist_app_query = "select APPOINTID, DATE_FORMAT(APPOINTDTC,'%Y-%m-%d %H:%i')  as APPOINTDTC ,DATE_FORMAT(IDENTIFYDTC,'%Y-%m-%d %H:%i')  as IDENTIFYDTC  from APPOINTMENT  where SAID ="+SAID ;
                ResultSet exist_app_query_rs = stmt.executeQuery(exist_app_query);
              
                while(exist_app_query_rs.next()){
                    applicant.put("RESULT","success");
                    applicant.put("MSG","예약");
                    applicant.put("SAID",SAID);
                    
                    applicant.put("APPOINTID",exist_app_query_rs.getInt(1));
                    applicant.put("APPOINTDTC", exist_app_query_rs.getString(2));
                    applicant.put("IDENTIFYDTC",exist_app_query_rs.getString(3));                  
                }                    
            }   

               String study_query = "select TITLE FROM STUDY where SID ="+sid ;
                ResultSet study_rs = stmt.executeQuery(study_query);
              
                while(study_rs.next()){
                 applicant.put("SID",sid);     
                    applicant.put("TITLE", study_rs.getString(1));
                             
                }    

            out.println(applicant);
  
       

        stmt.close();
        conn.close();
       
    }
    /*
    input: QRCODE, SID

    자원자가 방문하여 방문확인시 QRCODE를 가지고 신원 확인 - 핸드폰 및 이름 추가
    1. 가입안된경우
    2. 참여중인 연구가 없음
    3. 참여중인 연구가 이 연구가 아님  
    4. 본인확인과 관련없이 예약이 하나도 없는 경우 
    5. 연구에 대해 예약이 있음 (항상 1개임)
        - javascript에서 오늘 예약인지 아닌지 보여준다.
        -회원가입시 신분확인을 안한 경우 또는 한번도 실시기관에서 신분확인을 안한 경우
    */
    else if(type.equals("VISIT_TODAY")){
      

        String SID = request.getParameter("SID");
        String QRCODE = request.getParameter("QRCODE");
       //String SAID= request.getParameter("SAID");        
        JSONObject applicant = new JSONObject();
        int exist = 0;
        int applid=0;

        /* if(applid==0){ // 이름으로 서치
             String name_query = "select COUNT(APPLID), APPLID from APPLICANT where APPLNAME = '" + QRCODE +"'  ;";
            ResultSet name_rs = stmt.executeQuery(name_query);
        
            while(name_rs.next()){
                exist = name_rs.getInt(1);
                   if(exist>0) applid=name_rs.getInt("APPLID");
            }

        } */

                /* if(applid==0){ // 이름으로 서치
             String name_query = "select COUNT(APPLID), APPLID from APPLICANT where APPLNAME = '" + QRCODE +"'  ;";
            ResultSet name_rs = stmt.executeQuery(name_query);
        
            while(name_rs.next()){
                exist = name_rs.getInt(1);
                   if(exist>0) applid=name_rs.getInt("APPLID");
            }

        } */
        if(applid==0){ // QRCODE로 서치 
            
            String exist_query = "select COUNT(APPLID), APPLID from APPLICANT where QRCODE = '" + QRCODE +"'  ;";
            ResultSet exist_rs = stmt.executeQuery(exist_query);
       
            while(exist_rs.next()){
                exist = exist_rs.getInt(1);
                if(exist>0) applid=exist_rs.getInt("APPLID");

            }
        }

        if(applid==0){ // (QRCODE 값이 핸드폰 번호)로 서치 
            
            String cellphone = QRCODE.replaceAll("[^0-9]",""); 
            String phone_query = "select COUNT(APPLID), APPLID from APPLICANT where REPLACE(APPLPHONENUM, '-', '') = '" + cellphone +"' ;";
            ResultSet phone_rs = stmt.executeQuery(phone_query);
        
            while(phone_rs.next()){
                exist = phone_rs.getInt(1);
                 if(exist>0) applid=phone_rs.getInt("APPLID");
            }
        }


           
        if (applid==0){
            applicant.put("RESULT","error");
            applicant.put("MSG","회원아님");
            out.println(applicant);
            stmt.close();
            conn.close();
            return;
        }


        //회원 정보 조회: APPLID, PASS 체크
        String appl_query =  "SELECT APPLID, APPLNAME, APPLMAIL, APPLPHONENUM, APPLBRTHDTC, APPLSEX , PASS FROM APPLICANT where APPLID="+applid;
        ResultSet appl_rs = stmt.executeQuery(appl_query);
           
       // int applid=0;
        int pass=0;
        while(appl_rs.next()){
            applicant.put("APPLID", appl_rs.getInt(1));
            applicant.put("APPLNAME", appl_rs.getString(2));
            applicant.put("APPLMAIL", appl_rs.getString(3));
            applicant.put("APPLPHONENUM", appl_rs.getString(4));
            applicant.put("APPLBIRTH", appl_rs.getString(5));
            applicant.put("APPLSEX", appl_rs.getInt(6));
            applicant.put("PASS", appl_rs.getInt("PASS"));
            applid = appl_rs.getInt(1);
            pass= appl_rs.getInt("PASS");
        }

       
        //현재 참여중인 연구가 있는지 확인
        String exist_said_query = "select COUNT(SAID) as COUNT, IFNULL(SAID, 0) as SAID, IFNULL(SID,0) as SID from study_applicant  where  APPLID = "+applid+" and SAACTIVE =1 "; //살아있는 SAID 는 하나이므로  EXISTS 대신 COUNT 사용
        ResultSet exist_said_rs = stmt.executeQuery(exist_said_query);
        int said=0;
        int sid=0;
        int count=0;
        while(exist_said_rs.next()){
            count=exist_said_rs.getInt("COUNT");
            said = exist_said_rs.getInt("SAID");
            sid =exist_said_rs.getInt("SID");          
        }
    
        if(count==0) {    //2. 현재 참여중인 연구가 없음
            applicant.put("RESULT","error");
            applicant.put("MSG","참여중 연구 없음");
            applicant.put("SID",0);
            out.println(applicant);
            stmt.close();
            conn.close();
            return;

        }
        String study_query = "select TITLE FROM STUDY  WHERE SID = "+sid;
        ResultSet study_rs = stmt.executeQuery(study_query);
               
        while(study_rs.next()){
           applicant.put("SID",sid);                     
           applicant.put("TITLE", study_rs.getString(1));                   
    
       }

        if(Integer.parseInt(SID)!=sid) {   //3. 참여중인 연구가 이 연구가 아님
            applicant.put("RESULT","error");
            applicant.put("MSG","다른 연구 참여중");
 
            out.println(applicant);
            stmt.close();
            conn.close();
            return;
        }
           



        //SAID 에 대해 예약이 있는지 확인
        if(said !=0){ 
            int appoint_exist=0;                
            String appoint_exist_query = "select EXISTS (select * from APPOINTMENT where SAID = "+said +"  ) as success;";
            ResultSet appoint_exist_rs = stmt.executeQuery(appoint_exist_query);
                
            while(appoint_exist_rs.next()){
                appoint_exist = appoint_exist_rs.getInt(1);
            }
            
            if(appoint_exist==0)    {//4. 본인확인과 관련없이 예약이 하나도 없는 경우
                applicant.put("RESULT","error");
                applicant.put("MSG","예약없음");
                applicant.put("SAID",said);
                applicant.put("SID",sid);
                applicant.put("APPOINTID",0);
              
                

            }
            else{ // 5.연구에 대해 예약이 있음 (항상 1개임. javascript에서 오늘 예약인지 아닌지 보여준다.)
         
                String exist_app_query = "select APPOINTID, DATE_FORMAT(APPOINTDTC,'%Y-%m-%d %H:%i')  as APPOINTDTC ,DATE_FORMAT(IDENTIFYDTC,'%Y-%m-%d %H:%i')  as IDENTIFYDTC  from APPOINTMENT  where SAID ="+said ;
                ResultSet exist_app_query_rs = stmt.executeQuery(exist_app_query);
              
                while(exist_app_query_rs.next()){
                    applicant.put("RESULT","success");
                    applicant.put("MSG","예약");
                    applicant.put("SAID",said);
                    applicant.put("SID",sid);
                    applicant.put("APPOINTID",exist_app_query_rs.getInt(1));
                    applicant.put("APPOINTDTC", exist_app_query_rs.getString(2));
                    applicant.put("IDENTIFYDTC",exist_app_query_rs.getString(3));                  
                }                    
            }    
            
            out.println(applicant);
  
        }

        stmt.close();
        conn.close();
       
    }
    else if(type.equals("identity")){

        String SAID = request.getParameter("SAID");
        //String CONSENTID = request.getParameter("CONSENTID");
        String SID = request.getParameter("SID");  
        /*String APPLID = request.getParameter("APPLID");  
        String SID = request.getParameter("SID");  
        String SAID = request.getParameter("SAID");
        String CONSENTID = request.getParameter("CONSENTID");*/
        String APPOINTID = request.getParameter("APPOINTID");

        DecimalFormat df = new DecimalFormat("00");
        Calendar calendar = Calendar.getInstance();
        String year = Integer.toString(calendar.get(Calendar.YEAR)); 
        String month = df.format(calendar.get(Calendar.MONTH) + 1); 
        String day = df.format(calendar.get(Calendar.DATE)); 
        String hour = df.format(calendar.get(Calendar.HOUR_OF_DAY));
        String minute = df.format(calendar.get(Calendar.MINUTE));
        String second = df.format(calendar.get(Calendar.SECOND));    
        String today = year+"-"+month+"-"+day+" "+hour+":"+minute+":"+second;


        //study_applicant  테이블 last-identification=1 , sastage=4 으 로 update    
        String update_query = "UPDATE APPOINTMENT SET IDENTIFYDTC='"+today+"' WHERE APPOINTID="+APPOINTID;
        stmt.executeUpdate(update_query);

        // APPOINTMENT_LOG 저장 - UPDATE
        String appointmentLogPrevQuery = selectPreviousInformation(stmt, "APPOINTMENT_LOG", "APPOINTMENT", tableSchemaName);
        String appointmentLogInsertquery = appointmentLogPrevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from APPOINTMENT where APPOINTID="+APPOINTID;
        stmt.executeUpdate(appointmentLogInsertquery);
        
       
        // consent_subject 테이블 그룹에서 가장 최근 유효한 대면 동의서에 대한 대상자 동의 정보 update-> CSCSIDENTIFICATION=today, CS_contact_stage=3;
        // String update_CS_query = "UPDATE consent_subject SET CS_CONTACT_STAGE=3 , CS_VISITDTC='"+today+"' WHERE SAID="+SAID+"  and CS_CONTACT_STAGE=1  order by CSID desc LIMIT 1";
        //stmt.executeUpdate(update_CS_query);    
       
          //유효한 최종 동의서를 찾아  대상자 동의 정보 update-> CSCSIDENTIFICATION=today, CS_contact_stage=3;
        String consent_group_query = "SELECT CSGRPID FROM CONSENT_GROUP WHERE SID =" +SID;

        ResultSet group_rs = stmt.executeQuery(consent_group_query);
        while(group_rs.next()){
            Statement stmt1 = conn.createStatement();
            String search_consent_query = "select CONSENTID, CONTACT_COPTION from CONSENT where SID=" + SID +"  and CSGRPID = "+group_rs.getInt(1)+" and ISPUBLISH=1 order by CPUBLISHDTC DESC LIMIT 1";
            ResultSet consent_rs = stmt1.executeQuery(search_consent_query);
            String query_said_insert="";

            while(consent_rs.next()){    
                int consentid= consent_rs.getInt("CONSENTID") ;

                Statement stmt2 = conn.createStatement();                    

                String update_CS_query = "UPDATE consent_subject SET CS_CONTACT_STAGE=3 , CS_VISITDTC='"+today+"' WHERE SAID="+SAID+"  and CS_CONTACT_STAGE in (1,2,3)  and CONSENTID="+consentid;
                stmt2.executeUpdate(update_CS_query);

                //CONSENT_SUBJECT_LOG 저장
                String consentSubjectLogPrevQuery = selectPreviousInformation(stmt2, "CONSENT_SUBJECT_LOG", "CONSENT_SUBJECT", tableSchemaName);
                String consentSubjectLogInsertQuery = consentSubjectLogPrevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from CONSENT_SUBJECT where SAID="+SAID+" and CS_CONTACT_STAGE=3 and CONSENTID="+consentid;
                stmt2.executeUpdate(consentSubjectLogInsertQuery);

                stmt2.close();
            }
            stmt1.close();
        }
     
          //유효한 최종 동의서를 찾아  대상자 동의 정보 update-> CSCSIDENTIFICATION=today, CS_contact_stage=3;
      /*  String consent_group_query = "SELECT CSGRPID FROM CONSENT_GROUP WHERE SID =" +SID;

        ResultSet group_rs = stmt.executeQuery(consent_group_query);
        while(group_rs.next()){
                Statement stmt1 = conn.createStatement();
                String search_consent_query = "select CONSENTID, CONTACT_COPTION from CONSENT where SID=" + SID +"  and CSGRPID = "+group_rs.getInt(1)+" and ISPUBLISH=1 order by CPUBLISHDTC DESC LIMIT 1";
                ResultSet consent_rs = stmt1.executeQuery(search_consent_query);
                String query_said_insert="";
                while(consent_rs.next()){              
                    Statement stmt2 = conn.createStatement();                    
                    String update_CS_query = "UPDATE consent_subject SET CS_CONTACT_STAGE=3 , CS_VISITDTC='"+today+"' WHERE SAID="+SAID+"  and CS_CONTACT_STAGE=1  order by CSID desc LIMIT 1";
                     stmt2.executeUpdate(update_CS_query);
                    stmt2.close();
                }
                stmt1.close();
        }*/
      
      out.println(year+"-"+month+"-"+day+" "+hour+":"+minute);
     //LOG


    }
    /*
    APPLID 로 QRCODE를 찾아 리턴한다. API 테스트용으로 실제 사용하지 않는다.
    */
    else if(type.equals("get_QR")){
      
       
        String APPLID = request.getParameter("APPLID");

        String exist_query = "select COUNT(APPLID) as count, QRCODE from APPLICANT where APPLID = "+ APPLID +" and QRCODE is not null";
        ResultSet exist_rs = stmt.executeQuery(exist_query);
        String result = "";
        while(exist_rs.next()){
            if ( exist_rs.getInt("count")>0) result=exist_rs.getString("QRCODE");
        }

        out.println(result); 
      
       
    }
    /*
    신분증 등으로 offline에서 신원확인
    */
     else if(type.equals("save_pass")){

        String APPLID = request.getParameter("APPLID");
        String SID = request.getParameter("SID");  
        String SAID = request.getParameter("SAID");
        String APPOINTID = request.getParameter("APPOINTID");

        String update_query = "UPDATE APPLICANT SET PASS=2 WHERE APPLID="+APPLID;   
        stmt.executeUpdate(update_query);

        //APPLICANT_LOG 저장 - UPDATE
        String applicantLogPrevQuery = selectPreviousInformation(stmt, "APPLICANT_LOG", "APPLICANT", tableSchemaName);
        String applicantLogInsertquery = applicantLogPrevQuery+",'SITE', "+INVID+",'UPDATE', NOW() from APPLICANT where APPLID="+APPLID;
        stmt.executeUpdate(applicantLogInsertquery); 

        DecimalFormat df = new DecimalFormat("00");
        Calendar calendar = Calendar.getInstance();
        String year = Integer.toString(calendar.get(Calendar.YEAR)); 
        String month = df.format(calendar.get(Calendar.MONTH) + 1); 
        String day = df.format(calendar.get(Calendar.DATE)); 
        String hour = df.format(calendar.get(Calendar.HOUR_OF_DAY));
        String minute = df.format(calendar.get(Calendar.MINUTE));
        String second = df.format(calendar.get(Calendar.SECOND));    
        String today = year+"-"+month+"-"+day+" "+hour+":"+minute+":"+second;


        //study_applicant  테이블 last-identification=1 , sastage=4 으 로 update    
        String update_query1 = "UPDATE APPOINTMENT SET IDENTIFYDTC='"+today+"' WHERE APPOINTID="+APPOINTID;
        stmt.executeUpdate(update_query1);

        //APPOINTMENT_LOG 저장 - UPDATE
        String appointmentLogPrevQuery = selectPreviousInformation(stmt, "APPOINTMENT_LOG", "APPOINTMENT", tableSchemaName);
        String appointmentLogInsertquery = appointmentLogPrevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from APPOINTMENT where APPOINTID="+APPOINTID;
        stmt.executeUpdate(appointmentLogInsertquery);

        // consent_subject 테이블 그룹에서 가장 최근 유효한 대면 동의서에 대한 대상자 동의 정보 update-> CSCSIDENTIFICATION=today, CS_contact_stage=3;
        // String update_CS_query = "UPDATE consent_subject SET CS_CONTACT_STAGE=3 , CS_VISITDTC='"+today+"' WHERE SAID="+SAID+"  and CS_CONTACT_STAGE=1  order by CSID desc LIMIT 1";
        // stmt.executeUpdate(update_CS_query);



        //유효한 최종 동의서를 찾아  대상자 동의 정보 update-> CSCSIDENTIFICATION=today, CS_contact_stage=3;
        String consent_group_query = "SELECT CSGRPID FROM CONSENT_GROUP WHERE SID =" +SID;

        ResultSet group_rs = stmt.executeQuery(consent_group_query);
        while(group_rs.next()){
            Statement stmt1 = conn.createStatement();
            String search_consent_query = "select CONSENTID, CONTACT_COPTION from CONSENT where SID=" + SID +"  and CSGRPID = "+group_rs.getInt(1)+" and ISPUBLISH=1 order by CPUBLISHDTC DESC LIMIT 1";
            ResultSet consent_rs = stmt1.executeQuery(search_consent_query);
            String query_said_insert="";
            while(consent_rs.next()){   
                int consentid= consent_rs.getInt("CONSENTID") ;           
                Statement stmt2 = conn.createStatement();                    
                // String update_CS_query = "UPDATE consent_subject SET CS_CONTACT_STAGE=3 , CS_VISITDTC='"+today+"' WHERE SAID="+SAID+"  and CS_CONTACT_STAGE=1  order by CSID desc LIMIT 1";
                
                String update_CS_query = "UPDATE consent_subject SET CS_CONTACT_STAGE=3 , CS_VISITDTC='"+today+"' WHERE SAID="+SAID+"  and CS_CONTACT_STAGE in (1,2,3)  and CONSENTID="+consentid;
                stmt2.executeUpdate(update_CS_query);

                //CONSENT_SUBJECT_LOG 저장 - UPDATE(*)
                String consentSubjectPrevQuery = selectPreviousInformation(stmt, "CONSENT_SUBJECT_LOG", "CONSENT_SUBJECT", tableSchemaName);
                String consentSubjectLogInsertquery = consentSubjectPrevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from CONSENT_SUBJECT WHERE SAID="+SAID+"  and CS_CONTACT_STAGE in (1,2,3)  and CONSENTID="+consentid;
                stmt2.executeUpdate(consentSubjectLogInsertquery);  

                stmt2.close();
            }
            stmt1.close();
        }      


        out.println(year+"-"+month+"-"+day+" "+hour+":"+minute);

    }
    stmt.close();
    conn.close();
    

}catch(Exception e){
    e.printStackTrace();
    out.println(e.toString());
}
finally{
         if(stmt!=null) { try{stmt.close();} catch(Exception e){}}  stmt.close();
         if(conn!=null) { try{conn.close();} catch(Exception e){}}  conn.close();
}
%>

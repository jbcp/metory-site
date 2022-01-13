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
<%@page import="java.util.zip.Checksum"%>
<%@page import="java.util.zip.Adler32"%>
<%@page import="kr.jbcp.request.JbcpBCRequest"%>
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
    Class.forName("com.mysql.jdbc.Driver");
    String jdbcDriver = jdbcDriverValue;
    String tableSchemaName = jdbcDriverValue.split("/")[jdbcDriverValue.split("/").length-1].split("\\?")[0];

    Object object_ips = db_parser.parse(new FileReader("../config/ips.json"));
    JSONObject jobject_ips = (JSONObject) object_ips;       
    
    String dAppIp = (String)jobject_ips.get("dApp");
    String siteIp = (String)jobject_ips.get("site");
    
    Connection conn= DriverManager.getConnection(jdbcDriver,dbId, dbPass); 
    Statement stmt =null;
    stmt = conn.createStatement();

    int SITEID = (int)session.getAttribute("SITEID");
    int INVID = (int)session.getAttribute("INVID");
    String INVNAME = session.getAttribute("INVNAME").toString();
    String INVMAIL = session.getAttribute("INVMAIL").toString();
    String SITENAME = session.getAttribute("SITENAME").toString();

    try{
        //Load Action Type
        String type = request.getParameter("action");

        /*
            Load Study Info
            Input : SID
            Output : Study info(JSON)
        */
        if(type.equals("LOAD_STUDY_INFO")){
            JSONArray studies = new JSONArray();
            int sponsorId=0;
            String SPONSORNAME="";
            

            //Load Study information
            String SID = request.getParameter("SID");

            //Load Study info
            String load_study_detail_query = "SELECT SID, SPONSORID, PRTNO, TITLE, SAPPL, SSEX, SNUM, STARGET FROM STUDY WHERE SID = " + SID;
            ResultSet rs = stmt.executeQuery(load_study_detail_query);
           
            JSONObject study = new JSONObject();

            while(rs.next()){
                study.put("SID", rs.getInt(1));  
                sponsorId=rs.getInt(2);
                study.put("PRTNO", rs.getString(3));
                study.put("TITLE", rs.getString(4));
                study.put("SAPPL", rs.getString(5));
                study.put("SSEX", rs.getInt(6));
                study.put("SNUM", rs.getInt(7));
                study.put("STARGET", rs.getString(8));
            }

            String sponsor_name_query = "SELECT SPONSORNAME FROM SPONSOR WHERE sponsorId = " + sponsorId;
            ResultSet sponsor_name_rs = stmt.executeQuery(sponsor_name_query);
            
            while(sponsor_name_rs.next()){
                SPONSORNAME=sponsor_name_rs.getString(1);
            }

            study.put("SPONSOR", SPONSORNAME);  
            studies.add(study);

            stmt.close();
            conn.close();
            out.println(studies);           
        }

        else if(type.equals("LOAD_APPLICANT")){
            JSONArray applicants = new JSONArray();

            //Load Study information
            String SID = request.getParameter("SID");
            String CONSENTID = request.getParameter("CONSENTID");
            int SAID=0;
            String query1 = "select a.applid from applicant a, study_applicant sa2, consent_subject cs2 where sa2.APPLID=a.APPLID and cs2.CONSENTID = "+CONSENTID+" and cs2.SAID = sa2.SAID  group by sa2.applid order by sa2.SAID "; 
            ResultSet rs1 = stmt.executeQuery(query1);
            while(rs1.next()){
                Statement stmt2 = conn.createStatement();
                String query2 = "select cs.CSID, sa.SAID,sa.APPLID, sa.APPLDTC, sa.SASTAGE,  DATE_FORMAT(cs.CSREQUESTDTC,'%Y-%m-%d %H:%i')  as CSREQUESTDTC, DATE_FORMAT(cs.CSSTARTDTC,'%Y-%m-%d %H:%i')  as CSSTARTDTC , DATE_FORMAT(cs.CSENDDTC,'%Y-%m-%d %H:%i')  as CSENDDTC, DATE_FORMAT(cs.SUBJ_SIGNDTC,'%Y-%m-%d %H:%i')  as SUBJ_SIGNDTC,   DATE_FORMAT(cs.INV_SIGNDTC,'%Y-%m-%d %H:%i')  as INV_SIGNDTC, cs.CS_CONTACT_STAGE, cs.CS_UNCONTACT_STAGE, cs.CSIDENTIFICATION, sa.SAACTIVE,  DATE_FORMAT(sa.SACLOSEDTC,'%Y-%m-%d')  as SACLOSEDTC  from consent_subject cs, study_applicant sa where cs.CONSENTID = "+CONSENTID+" and cs.SAID = sa.SAID and sa.applid="+rs1.getInt(1)+" order by sa.said desc limit 1  ";//and sa.SASTAGE not in (9)  ORDER BY sa.SAID desc;"; //신청취소 제외
                ResultSet rs2 = stmt2.executeQuery(query2);

                int reserveid=0;
                 JSONObject applicant = new JSONObject();
                while(rs2.next()){
                   
                    applicant.put("CSID", rs2.getInt("cs.CSID"));
                    applicant.put("SAID", rs2.getInt("sa.SAID"));
                    applicant.put("APPLID", rs2.getInt("sa.APPLID"));
                    applicant.put("APPLDTC", rs2.getString("sa.APPLDTC"));
                    applicant.put("SASTAGE", rs2.getInt("sa.SASTAGE"));
                    SAID=rs2.getInt("sa.SAID");
                    applicant.put("CSREQUEST", rs2.getString("CSREQUESTDTC"));
                    applicant.put("CSSTART", rs2.getString("CSSTARTDTC"));
                    applicant.put("CSEND", rs2.getString("CSENDDTC"));
                    applicant.put("SIGN", rs2.getString("SUBJ_SIGNDTC"));
                    // applicant.put("LAR_SIGN", rs.getString("cs.LAR_SIGNDTC"));
                    applicant.put("INV_SIGN", rs2.getString("INV_SIGNDTC"));
                    applicant.put("CS_CONTACT_STAGE", rs2.getInt("cs.CS_CONTACT_STAGE"));
                    applicant.put("CS_UNCONTACT_STAGE", rs2.getInt("cs.CS_UNCONTACT_STAGE"));
                    applicant.put("CSPASS", rs2.getString("cs.CSIDENTIFICATION"));               
                    applicant.put("SAACTIVE", rs2.getInt("sa.SAACTIVE")); 
                    applicant.put("SACLOSEDTC", rs2.getString("SACLOSEDTC")); 
                }
                 //   Statement stmt11 = conn.createStatement();

                
            
                String applicant_query = "select APPLNAME, APPLMAIL,APPLPHONENUM, APPLBRTHDTC, APPLSEX from APPLICANT WHERE APPLID =  "+rs1.getInt(1);
                ResultSet applicant_rs = stmt2.executeQuery(applicant_query);
                                
                while(applicant_rs.next()){
                            applicant.put("APPLNAME", applicant_rs.getString(1));
                            applicant.put("APPLMAIL", applicant_rs.getString(2));
                            applicant.put("APPLPHONE", applicant_rs.getString(3));
                            applicant.put("APPLBIRTH", applicant_rs.getString(4));
                            applicant.put("APPLSEX", applicant_rs.getInt(5));
                }   

                // if(reserveid!=0){
                        //각 대상자의 마지막 예약정보 찾기
                String reserve_query = "select APPOINTID,  DATE_FORMAT(APPOINTDTC,'%Y-%m-%d %H:%i')  as  APPOINTDTC, DATE_FORMAT(IDENTIFYDTC,'%Y-%m-%d %H:%i')  as  IDENTIFYDTC, AFID, MEMO from APPOINTMENT WHERE SAID ="+ SAID+" order by APPOINTDTC desc LIMIT 1" ;
                ResultSet reserve_rs = stmt2.executeQuery(reserve_query);
                            
                while(reserve_rs.next()){
                                applicant.put("VISITDTC", reserve_rs.getString("APPOINTDTC"));
                                applicant.put("CSPASS", reserve_rs.getString("IDENTIFYDTC"));
                                applicant.put("APPOINTID", reserve_rs.getInt("APPOINTID"));  
                                applicant.put("AFID", reserve_rs.getInt("AFID"));
                                applicant.put("MEMO", reserve_rs.getString("MEMO"));             
                }            
                    // }

              //유효한 가장 최근 screening_id 를 찾는다.
            String exist_query = "select count(screening_id) , screening_id from SCREENING  where SID ="+SID + " and  valid =1 order by screening_id desc limit 1 ;";
            ResultSet exist_rs = stmt2.executeQuery(exist_query);
            int screening_id = 0;        
            while(exist_rs.next()){
               if(exist_rs.getInt(1)>0) screening_id= exist_rs.getInt(2) ;
               applicant.put("SCREENING_ID", screening_id) ;
            }       

             //survey_subject 테이블에서 이미 응답이 이루어졌는지 찾는다.
            String exist_submit_query = "select count(*)  from survey_subject  where SAID ="+SAID + " and SCREENING_ID= "+screening_id ;
            ResultSet exist_submit_rs = stmt2.executeQuery(exist_submit_query);
                
            while(exist_submit_rs.next()){
                if(exist_submit_rs.getInt(1)>0) 
               applicant.put("SUBMIT_SURVEY", 1) ;
               else applicant.put("SUBMIT_SURVEY", 0) ;
            }     

                    //    stmt11.close();
                applicants.add(applicant);
                 stmt2.close();
            
            }
         
            stmt.close();
            conn.close();
            out.println(applicants);

        }
  else if(type.equals("LOAD_CONSENT_APPLICANT")){
            JSONArray applicants = new JSONArray();

            //Load Study information
            String SID = request.getParameter("SID");
            String CONSENTID = request.getParameter("CONSENTID");
            int SAID=0;
            String query1 = "select a.applid from applicant a, study_applicant sa2, consent_subject cs2 where sa2.applid=a.applid and cs2.CONSENTID = "+CONSENTID+" and cs2.SAID = sa2.SAID  group by sa2.applid order by sa2.SAID;"; 
            ResultSet rs1 = stmt.executeQuery(query1);
            while(rs1.next()){
                Statement stmt2 = conn.createStatement();
                String query2 = "select cs.CSID, sa.SAID,sa.APPLID, sa.APPLDTC, sa.SASTAGE,  DATE_FORMAT(cs.CSREQUESTDTC,'%Y-%m-%d %H:%i')  as CSREQUESTDTC, DATE_FORMAT(cs.CSSTARTDTC,'%Y-%m-%d %H:%i')  as CSSTARTDTC , DATE_FORMAT(cs.CSENDDTC,'%Y-%m-%d %H:%i')  as CSENDDTC, DATE_FORMAT(cs.SUBJ_SIGNDTC,'%Y-%m-%d %H:%i')  as SUBJ_SIGNDTC,   DATE_FORMAT(cs.INV_SIGNDTC,'%Y-%m-%d %H:%i')  as INV_SIGNDTC, cs.CS_CONTACT_STAGE, cs.CS_UNCONTACT_STAGE, cs.CSIDENTIFICATION, sa.SAACTIVE,  DATE_FORMAT(sa.SACLOSEDTC,'%Y-%m-%d')  as SACLOSEDTC,  DATE_FORMAT(cs.CS_VISITDTC,'%Y-%m-%d %H:%i')  as CSVISITDTC from consent_subject cs, study_applicant sa where cs.CONSENTID = "+CONSENTID+" and cs.SAID = sa.SAID and sa.applid="+rs1.getInt(1)+" order by sa.said desc limit 1  ";//and sa.SASTAGE not in (9)  ORDER BY sa.SAID desc;"; //신청취소 제외
                ResultSet rs2 = stmt2.executeQuery(query2);

                int reserveid=0;
                 JSONObject applicant = new JSONObject();
                while(rs2.next()){
                   
                    applicant.put("CSID", rs2.getInt("cs.CSID"));
                    applicant.put("SAID", rs2.getInt("sa.SAID"));
                    applicant.put("APPLID", rs2.getInt("sa.APPLID"));
                    applicant.put("APPLDTC", rs2.getString("sa.APPLDTC"));
                    applicant.put("SASTAGE", rs2.getInt("sa.SASTAGE"));
                    SAID=rs2.getInt("sa.SAID");
                    applicant.put("CSREQUEST", rs2.getString("CSREQUESTDTC"));
                    applicant.put("CSSTART", rs2.getString("CSSTARTDTC"));
                    applicant.put("CSEND", rs2.getString("CSENDDTC"));
                    applicant.put("SIGN", rs2.getString("SUBJ_SIGNDTC"));
                    // applicant.put("LAR_SIGN", rs.getString("cs.LAR_SIGNDTC"));
                    applicant.put("INV_SIGN", rs2.getString("INV_SIGNDTC"));
                    applicant.put("CS_CONTACT_STAGE", rs2.getInt("cs.CS_CONTACT_STAGE"));
                    applicant.put("CS_UNCONTACT_STAGE", rs2.getInt("cs.CS_UNCONTACT_STAGE"));
                   // applicant.put("CSPASS", rs2.getString("cs.CSIDENTIFICATION"));               
                    applicant.put("SAACTIVE", rs2.getInt("sa.SAACTIVE")); 
                    applicant.put("SACLOSEDTC", rs2.getString("SACLOSEDTC")); 
                     applicant.put("CSVISITDTC", rs2.getString("CSVISITDTC")); 
                }
                 //   Statement stmt11 = conn.createStatement();

                
            
                String applicant_query = "select APPLNAME, APPLMAIL,APPLPHONENUM, APPLBRTHDTC, APPLSEX from APPLICANT WHERE APPLID =  "+rs1.getInt(1);
                ResultSet applicant_rs = stmt2.executeQuery(applicant_query);
                                
                while(applicant_rs.next()){
                            applicant.put("APPLNAME", applicant_rs.getString(1));
                            applicant.put("APPLMAIL", applicant_rs.getString(2));
                            applicant.put("APPLPHONE", applicant_rs.getString(3));
                            applicant.put("APPLBIRTH", applicant_rs.getString(4));
                            applicant.put("APPLSEX", applicant_rs.getInt(5));
                }   
/*
                // if(reserveid!=0){
                        //각 대상자의 마지막 예약정보 찾기
                String reserve_query = "select APPOINTID,  DATE_FORMAT(APPOINTDTC,'%Y-%m-%d %H:%i')  as  APPOINTDTC, DATE_FORMAT(IDENTIFYDTC,'%Y-%m-%d %H:%i')  as  IDENTIFYDTC, AFID, MEMO from APPOINTMENT WHERE SAID ="+ SAID+" order by APPOINTDTC desc LIMIT 1" ;
                ResultSet reserve_rs = stmt2.executeQuery(reserve_query);
                            
                while(reserve_rs.next()){
                                applicant.put("VISITDTC", reserve_rs.getString("APPOINTDTC"));
                                applicant.put("CSPASS", reserve_rs.getString("IDENTIFYDTC"));
                                applicant.put("APPOINTID", reserve_rs.getInt("APPOINTID"));  
                                applicant.put("AFID", reserve_rs.getInt("AFID"));
                                applicant.put("MEMO", reserve_rs.getString("MEMO"));             
                }             
                    // }

              //유효한 가장 최근 screening_id 를 찾는다.
            String exist_query = "select count(screening_id) , screening_id from SCREENING  where SID ="+SID + " and  valid =1 order by screening_id desc limit 1 ;";
            ResultSet exist_rs = stmt2.executeQuery(exist_query);
            int screening_id = 0;        
            while(exist_rs.next()){
               if(exist_rs.getInt(1)>0) screening_id= exist_rs.getInt(2) ;
               applicant.put("SCREENING_ID", screening_id) ;
            }       

             //survey_subject 테이블에서 이미 응답이 이루어졌는지 찾는다.
            String exist_submit_query = "select count(*)  from survey_subject  where SAID ="+SAID + " and SCREENING_ID= "+screening_id ;
            ResultSet exist_submit_rs = stmt2.executeQuery(exist_submit_query);
                
            while(exist_submit_rs.next()){
                if(exist_submit_rs.getInt(1)>0) 
               applicant.put("SUBMIT_SURVEY", 1) ;
               else applicant.put("SUBMIT_SURVEY", 0) ;
            }     */

                    //    stmt11.close();
                applicants.add(applicant);
                 stmt2.close();
            
            }
         
            stmt.close();
            conn.close();
            out.println(applicants);

        }
        else if(type.equals("LOAD_CONSENT_VERSION")){

            JSONArray consent_consents = new JSONArray();

         
            String SID = request.getParameter("SID");
            String CSGRPID = request.getParameter("CSGRPID");
             
            String query_consent = "SELECT CONSENTID, CVERSION, CONTACT_COPTION, INV_SIGN_COPTION FROM CONSENT WHERE ISPUBLISH =1 and SID = " + SID +" and CSGRPID = "+CSGRPID+" order by CPUBLISHDTC  DESC";
            ResultSet rs_consent = stmt.executeQuery(query_consent);

            while(rs_consent.next()){
                JSONObject consent = new JSONObject();
                consent.put("CONSENTID", rs_consent.getInt(1));
                consent.put("CVERSION", rs_consent.getString(2));
                consent.put("CONTACT_COPTION", rs_consent.getInt("CONTACT_COPTION"));
               consent.put("INV_SIGN_COPTION", rs_consent.getInt("INV_SIGN_COPTION"));
                consent_consents.add(consent);
            }

            stmt.close();
            conn.close();
            out.println(consent_consents);
        }
        else if(type.equals("GET_CONSENT_OPTION")){      
            String CONSENTID = request.getParameter("CONSENTID");
             
            String query_consent = "SELECT COUNT(CONSENTID) as COUNT, INV_SIGN_COPTION, CONTACT_COPTION FROM CONSENT WHERE CONSENTID = "+CONSENTID;
            ResultSet rs_consent = stmt.executeQuery(query_consent);
            JSONObject consent = new JSONObject();
            while(rs_consent.next()){           
                 consent.put("COUNT", rs_consent.getInt("COUNT"));          
                consent.put("INV_SIGN_COPTION", rs_consent.getInt("INV_SIGN_COPTION"));               
                 consent.put("CONTACT_COPTION", rs_consent.getInt("CONTACT_COPTION"));              
            }

            stmt.close();
            conn.close();
            out.println(consent);
        }
        else if(type.equals("LOAD_CONSENT_GROUP")){

            JSONArray consent_consents = new JSONArray();

  
            String SID = request.getParameter("SID");
             
            String query_consent = "SELECT CSGRPID, CSGRPTITLE, CSGRPTYPE FROM CONSENT_GROUP WHERE SID = " + SID + " and SITEID="+ SITEID+" order by CSGRPTYPE ASC ";
            ResultSet rs_consent = stmt.executeQuery(query_consent);

            while(rs_consent.next()){
                JSONObject consent = new JSONObject();
                consent.put("CSGRPID", rs_consent.getInt(1));
                consent.put("CSGRPTITLE", rs_consent.getString(2));
                consent.put("CSGRPTYPE", rs_consent.getInt(3));
                consent_consents.add(consent);
            }

            stmt.close();
            conn.close();
            out.println(consent_consents);
        }

        else if(type.equals("LOAD_CONSENT_QNA")){

            String SID = request.getParameter("SID");
            String SAID = request.getParameter("SAID");
         
            //String query = "select SAD.SAID, SAD.INVID, I.INVNAME, SAD.SADDTC, SAD.SADCONTENT FROM STUDY_APPLICANT SA, STUDY_APPLICANT_DETAIL SAD, INVESTIGATOR I WHERE SA.SAID = SAD.SAID and SAD.INVID = I.INVID and SA.SID = "+SID+" and SA.SAID = "+APPLID + " order by SAD.SADID ASC;";
            String query= "select q.SAID, q.INVID, q.QNADTC, q.QNACONTENT FROM STUDY_APPLICANT SA, QNA q WHERE SA.SAID = q.SAID and SA.SID = "+SID+" and q.SAID = "+SAID+" order by q.QNAID ASC;";

            ResultSet rs = stmt.executeQuery(query);

            JSONArray memos = new JSONArray();
            Statement stmt1 = conn.createStatement();

            while(rs.next()){
                JSONObject memo = new JSONObject();
                memo.put("SAID", rs.getInt(1));
                memo.put("INVID", rs.getInt(2));
                memo.put("QNADTC", rs.getString(3));
                memo.put("QNACONTENT", rs.getString(4));
                //if(rs.getInt(2) == INVID) memo.put("MYMEMO", "true");
                //else memo.put("MYMEMO", "false");
                if(rs.getInt(2) > 0){
                    memo.put("MYMEMO", "true");
                    String invname_query = "select INVNAME from INVESTIGATOR where INVID="+rs.getInt(2);
                    ResultSet invname_rs = stmt1.executeQuery(invname_query);
                    while(invname_rs.next()) memo.put("INVNAME", invname_rs.getString(1));
                    
                }
                else{
                    memo.put("MYMEMO", "false");
                    memo.put("INVNAME", null);
                }
                memos.add(memo);
            }
            stmt1.close();
            stmt.close();
            conn.close();
            out.println(memos);
        }
         //신청취소하지 않은 대상자들의   qna 중 연구자가 아직 확인하지 않은 대상자별 qna 의 개수 반환
        else if(type.equals("CHECK_QNA")){
            String SID = request.getParameter("SID");
            String CONSENTID = request.getParameter("CONSENTID");

            //String query = "select CS.SAID, count(q.QNACONTENT) from QNA q right outer join consent_subject CS on q.SAID = CS.SAID where CS.SID = "+SID+" and CS.CONSENTID = "+CONSENTID+" and q.ISREAD = 0 and CS.SASTAGE not in (9) group by CS.SAID";
   
            String query="select sa.SAID, count(q.QNACONTENT), q.ISREAD from QNA q, STUDY_APPLICANT sa where sa.SAID=q.SAID and q.ISREAD=0 and sa.SID="+SID+" and sa.SASTAGE not in (9)  group by sa.SAID";//sastage=9 는 신청취소
            ResultSet count_memo = stmt.executeQuery(query);

            JSONArray memo_count = new JSONArray();

            while(count_memo.next()){
                JSONObject memo = new JSONObject();
                memo.put("SAID", count_memo.getInt(1));
                memo.put("COUNT", count_memo.getInt(2));
                memo_count.add(memo);
            }

            stmt.close();
            conn.close();
            out.println(memo_count);        
        }

        else if(type.equals("UPDATE_READ_FLAG")){
            String SAID = request.getParameter("SAID");

            String query = "UPDATE QNA SET ISREAD = 1 WHERE SAID = "+SAID;
            stmt.executeUpdate(query);

            // QNA_LOG 저장 - UPDATE
            String QNALogPrevQuery = selectPreviousInformation(stmt, "QNA_LOG", "QNA", tableSchemaName);
            String QNALogInsertquery = QNALogPrevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from QNA WHERE SAID="+SAID;
            stmt.executeUpdate(QNALogInsertquery);

            stmt.close();
            conn.close();
        }

        else if(type.equals("ADD_QNA")){
            String SAID = request.getParameter("SAID");
            String QNACONTENT = request.getParameter("memo");
           
          
            DecimalFormat df = new DecimalFormat("00");
            Calendar calendar = Calendar.getInstance();

            String year = Integer.toString(calendar.get(Calendar.YEAR)); 
            String month = df.format(calendar.get(Calendar.MONTH) + 1); 
            String day = df.format(calendar.get(Calendar.DATE)); 
            String hour = df.format(calendar.get(Calendar.HOUR_OF_DAY));
            String minute = df.format(calendar.get(Calendar.MINUTE));
            String second = df.format(calendar.get(Calendar.SECOND));
        
            String today = year+"-"+month+"-"+day+" "+hour+":"+minute+":"+second;

            String query = "INSERT INTO QNA(SAID, INVID, QNADTC, QNACONTENT, SUBJ_FLAG, ISREAD) VALUES("+SAID+", "+INVID+", '"+today+"', '"+QNACONTENT+"', 2,1);";
            stmt.executeUpdate(query);
            int insertedQNAID = getLastInsertID(stmt);

            //QNA_LOG 저장 - CREATE
            String QNALogPrevQuery = selectPreviousInformation(stmt, "QNA_LOG", "QNA", tableSchemaName);
            String QNALogInsertquery = QNALogPrevQuery+",'SITE', "+INVID+",'CREATE',NOW() from QNA where QNAID="+insertedQNAID;
            stmt.executeUpdate(QNALogInsertquery);  

            JSONObject result = new JSONObject();
            result.put("today",today);
            result.put("INVNAME",INVNAME);
            out.println(result);
            stmt.close();
            conn.close();
        }
        /*
        요청중인 리스트를 읽어 선택후 csid arr 에 있는 모두 시작으로 저장.
        */
        else if(type.equals("start_explain_all")){
            JSONObject jb= new JSONObject();    
            String SID = request.getParameter("SID");
            String CSIDARRTMP = request.getParameter("CSIDARR");
            String CONSENTID = request.getParameter("CONSENTID");
            String CSIDARR[]= CSIDARRTMP.split(",");      

            DecimalFormat df = new DecimalFormat("00");
            Calendar calendar = Calendar.getInstance();
            String year = Integer.toString(calendar.get(Calendar.YEAR)); 
            String month = df.format(calendar.get(Calendar.MONTH) + 1); 
            String day = df.format(calendar.get(Calendar.DATE)); 
            String hour = df.format(calendar.get(Calendar.HOUR_OF_DAY));
            String minute = df.format(calendar.get(Calendar.MINUTE));
            String second = df.format(calendar.get(Calendar.SECOND));
            String today = year+"-"+month+"-"+day+" "+hour+":"+minute+":"+second;


            //1. CONSENT OPTION 을 확인하여 대면인지 비대면인지 조사하고 CSID 값을 찾는다.      
            //  int CSID = 0;                 
           
            String cs_stage_query="";
            String cversion="";
            String cfile_hash="";
     
            String c_query = "select  c.CONTACT_COPTION, c.CVERSION, c.CFILE_HASH from  CONSENT c where  c.CONSENTID=" + CONSENTID  ;
        
            // String csID_query = "select CONTACT_COPTION from  CONSENT  where  CONSENTID=" + CONSENTID ;
            ResultSet c_rs = stmt.executeQuery(c_query);
            int coption=0;
            while(c_rs.next()){
                        
                if (c_rs.getInt(1)==1){ //대면               
                    cs_stage_query=" CS_CONTACT_STAGE=5";
                    coption=1;
                }
                else {//비대면
                    cs_stage_query=" CS_UNCONTACT_STAGE=2";
                }
                cversion=c_rs.getString("CVERSION");
                cfile_hash=c_rs.getString("CFILE_HASH");      
            }    

            
            int saveToCrcp=1;
            String study_bc_query="SELECT spon.SPONSORNAME, s.PRTNO, s.BCCHANNEL  from SPONSOR spon, study s where s.SPONSORID=spon.SPONSORID and s.SID="+SID;
     
            ResultSet study_bc_rs = stmt.executeQuery(study_bc_query);      
            String sponsorname="";
            String prtno="";
            String channel="";
            while(study_bc_rs.next()){
                    sponsorname=study_bc_rs.getString("spon.SPONSORNAME");
                    prtno=study_bc_rs.getString("s.PRTNO");
                    channel=study_bc_rs.getString("s.BCCHANNEL");          
            }
            jb.put("1","1");


            for (int i=0 ; i<CSIDARR.length;i++ ){
                String sa_query="SELECT SAID FROM consent_subject WHERE CSID="+CSIDARR[i];
                int SAID=0;
                ResultSet sa_rs = stmt.executeQuery(sa_query);      
                jb.put("2","2");
                while(sa_rs.next()){
                        
                        SAID=sa_rs.getInt("SAID");          
                }
                jb.put("3","3");


                   JbcpBCRequest BCobj = new JbcpBCRequest(dAppIp);
                //   out.println(dAppIp);
                   String consent_idx= SITENAME + "consent_" + CONSENTID + "_s" + SAID;                             
                   String result=BCobj.ConsentExplanation(channel,INVMAIL,consent_idx, SITENAME, prtno, sponsorname, ""+SAID, cversion,cfile_hash, today);

 
                if(!result.equals("ok")) {

                    saveToCrcp=0; //BC 저장이 안된경우 CRCP에도 저장안되게 한다.
                    jb.put("BCERROR", 1);
                }    
                else jb.put("BCERROR", 0);            
                //out.println(result);
                jb.put("BCRESULT", result);
                
                if(saveToCrcp==1){
                    String query ="UPDATE CONSENT_SUBJECT SET CSSTARTDTC = '"+today+"', "+cs_stage_query+" WHERE CSID="+CSIDARR[i]+";";
                  
                    stmt.executeUpdate(query);

                    // CONSENT_SUBJECT 저장 - UPDATE
                    String consentSubjectLogPrevQuery = selectPreviousInformation(stmt, "CONSENT_SUBJECT_LOG", "CONSENT_SUBJECT", tableSchemaName);
                    String consentSubjectLogInsertquery = consentSubjectLogPrevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from CONSENT_SUBJECT where CSID="+CSIDARR[i];
                    stmt.executeUpdate(consentSubjectLogInsertquery);
                }
                jb.put("4","4");
            }  
            //로그 저장(*여기서 해야하나?)

            stmt.close();
            conn.close();
            jb.put("DTC", today);
            out.print(jb);
            // out.print("success_"+today);
        }
     else if(type.equals("GETBCSTAGE")){
            //String SID = request.getParameter("SID");

             String SID = request.getParameter("SID");


        String study_bc_query="SELECT BCSTAGE  from study where SID="+SID;
        ResultSet study_bc_rs = stmt.executeQuery(study_bc_query);      
        int bc_stage=0;
        while(study_bc_rs.next()){
           bc_stage=study_bc_rs.getInt("BCSTAGE");          
        }
        
            stmt.close();
            conn.close();
           // jb.put("DTC", today);
            out.print(bc_stage);
        }
        else if(type.equals("START_EXPLAIN")){
            //String SID = request.getParameter("SID");
            String CONSENTID = request.getParameter("CONSENTID");
            String SAID = request.getParameter("SAID");
            String SID = request.getParameter("SID");

            String COPTION=request.getParameter("COPTION");
            DecimalFormat df = new DecimalFormat("00");
            Calendar calendar = Calendar.getInstance();
            String year = Integer.toString(calendar.get(Calendar.YEAR)); 
            String month = df.format(calendar.get(Calendar.MONTH) + 1); 
            String day = df.format(calendar.get(Calendar.DATE)); 
            String hour = df.format(calendar.get(Calendar.HOUR_OF_DAY));
            String minute = df.format(calendar.get(Calendar.MINUTE));
            String second = df.format(calendar.get(Calendar.SECOND));
            String today = year+"-"+month+"-"+day+" "+hour+":"+minute+":"+second;


            //1. CONSENT OPTION 을 확인하여 대면인지 비대면인지 조사하고 CSID 값을 찾는다.      
            int CSID = 0;                 
           
            String cs_stage_query="";
            String cversion="";
            String cfile_hash="";
    
            String csID_query = "select cs.CSID, c.CVERSION, c.CFILE_HASH ,c.CONTACT_COPTION from CONSENT_SUBJECT cs, CONSENT c where cs.SAID=" + SAID  +"  and c.CONSENTID=" + CONSENTID +" and cs.CONSENTID=c.CONSENTID";
            ResultSet csID_rs = stmt.executeQuery(csID_query);
            int coption=Integer.parseInt(COPTION);

            while(csID_rs.next()){
                CSID = csID_rs.getInt("cs.CSID");               
                if (csID_rs.getInt("c.CONTACT_COPTION")==1){ //대면               
                    cs_stage_query=" CS_CONTACT_STAGE=5";
                      //ConsentSignSubject(channel_name, user_id, consent_idx, site_id, protocol_no, subject_consent_sign_time, subject_sign_hash);
                    coption=1;

                }
                else {//비대면
                    cs_stage_query=" CS_UNCONTACT_STAGE=2";
                }
                cversion=csID_rs.getString("CVERSION");
                cfile_hash=csID_rs.getString("CFILE_HASH");        
            }     

            JSONObject jb= new JSONObject();    
            int saveToCrcp=1;

            //대면인 경우 BC저장
            // if(coption==1){  
            String study_bc_query="SELECT spon.SPONSORNAME, s.PRTNO, s.BCCHANNEL  from SPONSOR spon, study s where s.SPONSORID=spon.SPONSORID and s.SID="+SID;
            ResultSet study_bc_rs = stmt.executeQuery(study_bc_query);      
            String sponsorname="";
            String prtno="";
            String channel="";
            while(study_bc_rs.next()){
                sponsorname = study_bc_rs.getString("spon.SPONSORNAME");
                prtno = study_bc_rs.getString("s.PRTNO");
                channel = study_bc_rs.getString("s.BCCHANNEL");          
            }

            JbcpBCRequest BCobj = new JbcpBCRequest(dAppIp);
            // out.println(dAppIp);
            String consent_idx = SITENAME + "consent_" + CONSENTID + "_s" + SAID;                             
            String result = BCobj.ConsentExplanation(channel,INVMAIL,consent_idx, SITENAME, prtno, sponsorname, ""+SAID, cversion,cfile_hash, today);

            if(!result.equals("ok")) {
                saveToCrcp=0; //BC 저장이 안된경우 CRCP에도 저장안되게 한다.
                jb.put("BCERROR", 1);
            }    
            else jb.put("BCERROR", 0);            
            // out.println(result);
            jb.put("BCRESULT", result);
            //}            

            if(saveToCrcp==1){
                //CRCP 저장
                String query ="UPDATE CONSENT_SUBJECT SET CSSTARTDTC = '"+today+"', "+cs_stage_query+" WHERE CSID = "+CSID;
                stmt.executeUpdate(query);

                //CONSENT_SUBJECT_LOG 저장 - UPDATE
                String consentSubjectLogPrevQuery = selectPreviousInformation(stmt, "CONSENT_SUBJECT_LOG", "CONSENT_SUBJECT", tableSchemaName);
                String consentSubjectLogInsertquery = consentSubjectLogPrevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from CONSENT_SUBJECT WHERE CSID = "+CSID;
                stmt.executeUpdate(consentSubjectLogInsertquery);
            
                //로그 저장
                String applID_query = "select APPLID from STUDY_APPLICANT where SAID="+SAID;
                ResultSet applID_rs = stmt.executeQuery(applID_query);
                int APPLID = 0;
                while(applID_rs.next()){
                    APPLID = applID_rs.getInt(1);
                }

            }
        
            stmt.close();
            conn.close();
            jb.put("DTC", today);
            out.print(jb);
        }

        else if(type.equals("END_EXPLAIN")){
            String SID = request.getParameter("SID");
            String CONSENTID = request.getParameter("CONSENTID");
            String SAID = request.getParameter("SAID");

            int ACTIONCODE=6; //설명종료
        
            DecimalFormat df = new DecimalFormat("00");
            Calendar calendar = Calendar.getInstance();
            String year = Integer.toString(calendar.get(Calendar.YEAR)); 
            String month = df.format(calendar.get(Calendar.MONTH) + 1); 
            String day = df.format(calendar.get(Calendar.DATE)); 
            String hour = df.format(calendar.get(Calendar.HOUR_OF_DAY));
            String minute = df.format(calendar.get(Calendar.MINUTE));
            String second = df.format(calendar.get(Calendar.SECOND));
            String today = year+"-"+month+"-"+day+" "+hour+":"+minute+":"+second;


            //1. CONSENT OPTION 을 확인하여 대면인지 비대면인지 조사하고 CSID 값을 찾는다.           

            int CSID = 0;                 

            String cs_stage_query="";
            String csID_query = "select cs.CSID, c.CONTACT_COPTION from CONSENT_SUBJECT cs, CONSENT c where cs.SAID=" + SAID  +"  and c.CONSENTID=" + CONSENTID +" and cs.CONSENTID=c.CONSENTID";
            ResultSet csID_rs = stmt.executeQuery(csID_query);
    
            while(csID_rs.next()){
                CSID = csID_rs.getInt(1);               
                if (csID_rs.getInt(2)==1){ //대면               
                    cs_stage_query=" CS_CONTACT_STAGE=6";
                }
                else {//비대면
                    cs_stage_query=" CS_UNCONTACT_STAGE=3";
                }
            }
            String query ="UPDATE CONSENT_SUBJECT SET CSENDDTC = '"+today+"', "+cs_stage_query+" WHERE CSID = "+CSID;
            stmt.executeUpdate(query);

            //CONSENT_SUBJECT_LOG 저장
            String consentSubjectLogPrevQuery = selectPreviousInformation(stmt, "CONSENT_SUBJECT_LOG", "CONSENT_SUBJECT", tableSchemaName);
            String consentSubjectLogInsertquery = consentSubjectLogPrevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from CONSENT_SUBJECT where CSID="+CSID;
            stmt.executeUpdate(consentSubjectLogInsertquery);
        
            //2. 로그 저장
            /*String applID_query = "select APPLID from STUDY_APPLICANT where SAID=" + SAID ;
            ResultSet applID_rs = stmt.executeQuery(applID_query);
            int APPLID = 0;
            while(applID_rs.next()){
                APPLID = applID_rs.getInt(1);
            }
            String insert_action_query = "INSERT INTO SUBJLOG(SAID, APPLID, LOGCONTENT, LOGDTC) values("+SAID+","+APPLID+",'설명 종료','"+today+"')";
            log("[METORY log]"+"\t||\t[SITEID]="+SITEID+"\t||\t[INVID]="+INVID+"\t||\t[type]="+type+"\t||\t[QUERY]="+insert_action_query.replace("'", "\'"));
            stmt.executeUpdate(insert_action_query);     */

            stmt.close();
            conn.close();
            out.print("success");
        }
  /*
        설명 중인 리스트를 읽어 선택후 csid arr 에 있는 모두 종료로 저장.
        */
        else if(type.equals("end_explain_all")){
            //String SID = request.getParameter("SID");
            String CSIDARRTMP = request.getParameter("CSIDARR");
            String CONSENTID = request.getParameter("CONSENTID");
            String CSIDARR[]= CSIDARRTMP.split(",");
        
            DecimalFormat df = new DecimalFormat("00");
            Calendar calendar = Calendar.getInstance();
            String year = Integer.toString(calendar.get(Calendar.YEAR)); 
            String month = df.format(calendar.get(Calendar.MONTH) + 1); 
            String day = df.format(calendar.get(Calendar.DATE)); 
            String hour = df.format(calendar.get(Calendar.HOUR_OF_DAY));
            String minute = df.format(calendar.get(Calendar.MINUTE));
            String second = df.format(calendar.get(Calendar.SECOND));
            String today = year+"-"+month+"-"+day+" "+hour+":"+minute+":"+second;


            //1. CONSENT OPTION 을 확인하여 대면인지 비대면인지 조사하고 CSID 값을 찾는다.      
          //  int CSID = 0;                 
           
            String cs_stage_query="";
            String csID_query = "select CONTACT_COPTION from  CONSENT  where  CONSENTID=" + CONSENTID ;
            ResultSet csID_rs = stmt.executeQuery(csID_query);
    
            while(csID_rs.next()){
                        
                if (csID_rs.getInt(1)==1){ //대면               
                    cs_stage_query=" CS_CONTACT_STAGE=6";
                }
                else {//비대면
                    cs_stage_query=" CS_UNCONTACT_STAGE=3";
                }
            }    

        
            for (int i=0 ; i<CSIDARR.length;i++ ){
                String query ="UPDATE CONSENT_SUBJECT SET CSENDDTC = '"+today+"', "+cs_stage_query+" WHERE CSID="+CSIDARR[i]+";";
                stmt.executeUpdate(query);

                // CONSENT_SUBJECT_LOG 저장 - UPDATE
                String consentSubjectLogPrevQuery = selectPreviousInformation(stmt, "CONSENT_SUBJECT_LOG", "CONSENT_SUBJECT", tableSchemaName);
                String consentSubjectLogInsertQuery = consentSubjectLogPrevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from CONSENT_SUBJECT where CSID="+CSIDARR[i];
                stmt.executeUpdate(consentSubjectLogInsertQuery);
            }
        
            //로그 저장

            stmt.close();
            conn.close();
            out.print("success_"+today);
        }
        else if(type.equals("VIEW_CONSENT")){


     
          
            String SAID = request.getParameter("SAID");  
            String SID = request.getParameter("SID");      
            String CONSENTID = request.getParameter("CONSENTID");  
           JSONArray consentArr = new JSONArray();  

              


                 JSONObject consent = new JSONObject();    
           String bc_query = "select BCCHANNEL, BCSTAGE FROM  STUDY WHERE SID ="+SID;
            ResultSet bc_rs = stmt.executeQuery(bc_query);     
            while(bc_rs.next()){
               
                consent.put("BCCHANNEL", bc_rs.getString("BCCHANNEL"));
                consent.put("BCSTAGE", bc_rs.getInt("BCSTAGE"));
            }

            //1. find CONSNETID, CVERSION with SID from CONSENT TABLE
            //2. get all lists with CONSENTID from CONSENT_DETAIL
            //3. get SIGNDTC, SIGN_STR  with [SAID,CONSENTID] from CONSENT_SUBJECT
            String query = "select CONSENTID, CVERSION, CFILE, CPUBLISHDTC from CONSENT where CONSENTID=" + CONSENTID ;
            ResultSet rs = stmt.executeQuery(query);
            
            String CVERSION="";
                
          
            while(rs.next()){        
                 consent.put("INVNAME",INVNAME);  
                consent.put("CONSENTID", rs.getInt(1));
                consent.put("CVERSION", rs.getString(2));
                consent.put("CFILE", rs.getString(3));
                consent.put("CPUBLISHDTC", rs.getString(4));           
            }
            consentArr.add(consent);


            String consent_detail = "SELECT CDID,CDIDNUM, CDTITLE,  CDCONTENT FROM CONSENT_DETAIL WHERE  CONSENTID = " + CONSENTID +" order by CDIDNUM asc";
            ResultSet c_detail = stmt.executeQuery(consent_detail);
            JSONArray consent_details = new JSONArray();

            while(c_detail.next()){
                JSONObject detail = new JSONObject();
                detail.put("CDID", c_detail.getInt(1));          
                detail.put("CDIDNUM", c_detail.getInt(2));
                detail.put("CDTITLE", c_detail.getString(3));
                detail.put("CDCONTENT", c_detail.getString(4));

                consent_details.add(detail);
            }

            consentArr.add(consent_details);  

            String ca_query = "SELECT  DATE_FORMAT(   SUBJ_SIGNDTC ,'%Y-%m-%d %H:%i' )  , SUBJ_SIGN, SUBJ_SIGN_NAME  FROM CONSENT_SUBJECT WHERE  SAID = " + SAID +" AND CONSENTID="+CONSENTID;
            ResultSet ca_query_rs = stmt.executeQuery(ca_query);
            
            JSONObject caobj = new JSONObject();
            while(ca_query_rs.next()){
                
                caobj.put("SIGNDTC", ca_query_rs.getString(1));          
                caobj.put("SIGN", ca_query_rs.getString(2));
                caobj.put("SIGN_NAME", ca_query_rs.getString(3));

            
                //consent_details.add(detail);
            }

            consentArr.add(caobj);   

            stmt.close();
            conn.close();
            out.print(consentArr);
        }

    
        else if(type.equals("INV_SIGN")){       
            int ACTIONCODE=8; // 동의서 확인서명

     
            String SAID = URLDecoder.decode(request.getParameter("SAID"),"UTF-8");
            String SID = URLDecoder.decode(request.getParameter("SID"),"UTF-8");
        
            String CONSENTID = URLDecoder.decode(request.getParameter("CONSENTID"),"UTF-8");
            String INV_SIGN_NAME = URLDecoder.decode(request.getParameter("CSNAME"),"UTF-8" );
            String INV_SIGN = URLDecoder.decode(request.getParameter("CSSIGN"),"UTF-8" );
            String INV_SIGNDTC = URLDecoder.decode(request.getParameter("CSDTC"),"UTF-8" );

            //out.println("CSNAME"+CSNAME+"  CSSIGN="+CSSIGN+"  SIGNDTC= "+SIGNDTC);
                     
            JSONArray info = new JSONArray();
            JSONObject data = new JSONObject();       
      
            //0  check invname==inv_sign_name-- 보류
            //1. find csid with [CONSENTID and SAID] 
            //2. update @csid , INV_SIGNDTC, INV_SIGN_STR, INV_SIGN_NAME, CSSTAGE, on Consent_subject table 
           
            String find_csid_query = "select CS.CSID, CS.CSSTARTDTC, C.CVERSION, c.CONTACT_COPTION, c.CSGRPID as CSGRPID, IFNULL(c.CFILE_HASH, '') as CFILE_HASH from CONSENT_SUBJECT  CS  , CONSENT C where CS.CONSENTID =C.CONSENTID and CS.SAID = " + SAID +" and CS.CONSENTID=" + CONSENTID;
            ResultSet csid_rs = stmt.executeQuery(find_csid_query);
            int CSID = 0;
            String CVERSION="";
            String CSSTARTDTC="";
            String CSSTAGE="";
            int CSGRPID=0; 

            while(csid_rs.next()){
                CSID = csid_rs.getInt(1);
                CSSTARTDTC=csid_rs.getString(2);
                CVERSION=csid_rs.getString(3);
                data.put("CONTACT_COPTION", csid_rs.getInt(4));
                 
                if(csid_rs.getInt(4)==1){
                    CSSTAGE="CS_CONTACT_STAGE=8 , CSCLOSE=1";
                }
                else {
                    CSSTAGE="CS_UNCONTACT_STAGE=6 , CSCLOSE=1";
                }
                CSGRPID=csid_rs.getInt("CSGRPID");
                data.put("CFILE_HASH", csid_rs.getString("CFILE_HASH"));
            }           

            //bc 저장     

            String study_bc_query="SELECT   s.PRTNO, s.BCCHANNEL  from study s where   s.SID="+SID;
            ResultSet study_bc_rs = stmt.executeQuery(study_bc_query);      
            
            String prtno="";
            String channel="";
            while(study_bc_rs.next()){
            
            prtno=study_bc_rs.getString("s.PRTNO");
            channel=study_bc_rs.getString("s.BCCHANNEL");          
            }

            //ConsentSignInvestigator(channel_name, user_id, consent_idx, site_id, protocol_no, investigator_id, investigator_consent_sign_time)
            JbcpBCRequest BCobj = new JbcpBCRequest(dAppIp);
        
            String consent_idx= SITENAME + "consent_" + CONSENTID + "_s" + SAID;          

            String result=BCobj.ConsentSignInvestigator(channel,INVMAIL,consent_idx, SITENAME, prtno,INVNAME, INV_SIGNDTC);
    
            data.put("RESULT", result);

            //bc 저장후 crcp 저장
            if(result.equals("ok")){
                String update_CONSENT_SUBJECT_query = "UPDATE CONSENT_SUBJECT SET INVID="+INVID+", INV_SIGNDTC='"+ INV_SIGNDTC+"' , INV_SIGN = '"+INV_SIGN+"' , INV_SIGN_NAME='"+INV_SIGN_NAME+"', "+ CSSTAGE+" WHERE CSID = "+CSID;
                stmt.executeUpdate(update_CONSENT_SUBJECT_query);  

                // CONSENT_SUBJECT_LOG 저장 - UPDATE
                String consentSubjectLogPrevQuery = selectPreviousInformation(stmt, "CONSENT_SUBJECT_LOG", "CONSENT_SUBJECT", tableSchemaName);
                String consentSubjectLogInsertQuery = consentSubjectLogPrevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from CONSENT_SUBJECT WHERE CSID = "+CSID;
                stmt.executeUpdate(consentSubjectLogInsertQuery);
            }
            /*  String SPONSOR_query = "select sp.SPONSORNAME, s.PRTNO, s.BCCHANNEL, s.BCSTAGE FROM SPONSOR sp, STUDY s WHERE sp.SPONSORID = s.SPONSORID and s.SID ="+SID;
            ResultSet SPONSOR_rs = stmt.executeQuery(SPONSOR_query);
            String SPONSOR_name = "";
            String PRTNO = "";
            while(SPONSOR_rs.next()){
                SPONSOR_name = SPONSOR_rs.getString(1);
                PRTNO = SPONSOR_rs.getString(2);
                data.put("BCCHANNEL", SPONSOR_rs.getString("s.BCCHANNEL"));
                data.put("BCSTAGE", SPONSOR_rs.getInt("s.BCSTAGE"));
            }
            
            String inv_query = "select INVMAIL FROM INVESTIGATOR WHERE INVID  ="+INVID;
            ResultSet inv_rs = stmt.executeQuery(inv_query);
            while(inv_rs.next()){    
               data.put("INVMAIL", inv_rs.getString(1));
            }

          
            data.put("CSSTARTDTC", CSSTARTDTC);
            data.put("INVNAME", INVNAME);

            data.put("PRTNO", PRTNO);
            data.put("SITENAME", SITENAME);
            data.put("SPONSOR", SPONSOR_name);  

            data.put("DAPPIP", dAppIp);


            String find_grouptype_query = "select CSGRPTYPE, CSGRPTITLE from CONSENT_GROUP  where CSGRPID = " + CSGRPID;
            ResultSet grp_rs = stmt.executeQuery(find_grouptype_query);
            while(grp_rs.next()){    
               data.put("CSGRPTYPE", grp_rs.getInt(1));
            }
*/
            data.put("SITENAME", SITENAME);
            String get_appl_info_query = "select a.APPLID , a.APPLPHONENUM, a.APPLNAME from STUDY_APPLICANT sa, APPLICANT a   where sa.APPLID=a.APPLID and sa.SAID = " + SAID;
            ResultSet get_appl_info_rs = stmt.executeQuery(get_appl_info_query);
            while(get_appl_info_rs.next()){    
                data.put("APPLID", get_appl_info_rs.getInt(1));
                data.put("APPLPHONENUM", get_appl_info_rs.getString(2));
                data.put("APPLNAME", get_appl_info_rs.getString(3));
            }
            info.add(data);
            stmt.close();
            conn.close();
            //out.print(data);
            out.print(info);
        }
         /*  else if(type.equals("GET_BC_PARAMS")){     


            String SAID = request.getParameter("SAID");
            String SID = request.getParameter("SID");
        
            String CONSENTID = request.getParameter("CONSENTID");
          //String INV_SIGN_NAME = URLDecoder.decode(request.getParameter("CSNAME"),"UTF-8" );
          // String INV_SIGN = URLDecoder.decode(request.getParameter("CSSIGN"),"UTF-8" );
          // String INV_SIGNDTC = URLDecoder.decode(request.getParameter("CSDTC"),"UTF-8" );


            //out.println("CSNAME"+CSNAME+"  CSSIGN="+CSSIGN+"  SIGNDTC= "+SIGNDTC);
                     
            JSONArray info = new JSONArray();
            JSONObject data = new JSONObject();       
      
            //0  check invname==inv_sign_name-- 보류
            //1. find csid with [CONSENTID and SAID] 
            //2. update @csid , INV_SIGNDTC, INV_SIGN_STR, INV_SIGN_NAME, CSSTAGE, on Consent_subject table 
            //3. insert new line on SUBJLOG,  
            String find_csid_query = "select CS.CSID, DATE_FORMAT( CS.CSSTARTDTC ,'%Y-%m-%d %H:%i' ) , C.CVERSION, c.CONTACT_COPTION, c.CSGRPID as CSGRPID, IFNULL(c.CFILE_HASH, '') as CFILE_HASH from CONSENT_SUBJECT  CS  , CONSENT C where CS.CONSENTID =C.CONSENTID and CS.SAID = " + SAID +" and CS.CONSENTID=" + CONSENTID;
            ResultSet csid_rs = stmt.executeQuery(find_csid_query);
            int CSID = 0;
            String CVERSION="";
            String CSSTARTDTC="";
            String CSSTAGE="";
           int CSGRPID=0; 

            while(csid_rs.next()){
                CSID = csid_rs.getInt(1);
                CSSTARTDTC=csid_rs.getString(2);
                CVERSION=csid_rs.getString(3);
                data.put("CONTACT_COPTION", csid_rs.getInt(4));
                 
                if(csid_rs.getInt(4)==1){
                    CSSTAGE="CS_CONTACT_STAGE=8 , CSCLOSE=1";
                }
                else {
                    CSSTAGE="CS_UNCONTACT_STAGE=6 , CSCLOSE=1";
                }
                CSGRPID=csid_rs.getInt("CSGRPID");
                data.put("CFILE_HASH", csid_rs.getString("CFILE_HASH"));
            }           

           // String update_CONSENT_SUBJECT_query = "UPDATE CONSENT_SUBJECT SET INVID="+INVID+", INV_SIGNDTC='"+ INV_SIGNDTC+"' , INV_SIGN = '"+INV_SIGN+"' , INV_SIGN_NAME='"+INV_SIGN_NAME+"', "+ CSSTAGE+" WHERE CSID = "+CSID;
           // log("[METORY log]"+"\t||\t[SITEID]="+SITEID+"\t||\t[INVID]="+INVID+"\t||\t[type]="+type+"\t||\t[QUERY]="+update_CONSENT_SUBJECT_query.replace("'", "\'"));
         //   stmt.executeUpdate(update_CONSENT_SUBJECT_query);  

            String SPONSOR_query = "select sp.SPONSORNAME, s.PRTNO, s.BCCHANNEL, s.BCSTAGE FROM SPONSOR sp, STUDY s WHERE sp.SPONSORID = s.SPONSORID and s.SID ="+SID;
            ResultSet SPONSOR_rs = stmt.executeQuery(SPONSOR_query);
            String SPONSOR_name = "";
            String PRTNO = "";
            while(SPONSOR_rs.next()){
                SPONSOR_name = SPONSOR_rs.getString(1);
                PRTNO = SPONSOR_rs.getString(2);
                data.put("BCCHANNEL", SPONSOR_rs.getString("s.BCCHANNEL"));
                data.put("BCSTAGE", SPONSOR_rs.getInt("s.BCSTAGE"));
            }


            
            String inv_query = "select INVMAIL FROM INVESTIGATOR WHERE INVID  ="+INVID;
            ResultSet inv_rs = stmt.executeQuery(inv_query);
            while(inv_rs.next()){    
               data.put("INVMAIL", inv_rs.getString(1));
            } 

          
            data.put("CSSTARTDTC", CSSTARTDTC);
            data.put("INVNAME", INVNAME);

            data.put("PRTNO", PRTNO);
            data.put("SITENAME", SITENAME);
            data.put("SPONSOR", SPONSOR_name);  

            data.put("DAPPIP", dAppIp);


          String find_grouptype_query = "select CSGRPTYPE, CSGRPTITLE from CONSENT_GROUP  where CSGRPID = " + CSGRPID;
            ResultSet grp_rs = stmt.executeQuery(find_grouptype_query);
            while(grp_rs.next()){    
               data.put("CSGRPTYPE", grp_rs.getInt(1));
            }

       String get_appl_info_query = "select a.APPLID , a.APPLPHONENUM, a.APPLNAME from STUDY_APPLICANT sa, APPLICANT a   where sa.APPLID=a.APPLID and sa.SAID = " + SAID;
            ResultSet get_appl_info_rs = stmt.executeQuery(get_appl_info_query);
            while(get_appl_info_rs.next()){    
               data.put("APPLID", get_appl_info_rs.getInt(1));
                data.put("APPLPHONENUM", get_appl_info_rs.getString(2));
                 data.put("APPLNAME", get_appl_info_rs.getString(3));
            }
            info.add(data);
            stmt.close();
            conn.close();
            //out.print("success");
            out.print(info);
        }*/
        else if(type.equals("SAVE_VISITDTC")){
            String SAID = request.getParameter("SAID");
            String SID = request.getParameter("SID");
            String CONSENTID = request.getParameter("CONSENTID");
            String VISITDTC = request.getParameter("VISITDTC");
         
            int SASTAGE=2; //예약
            

           /* String query = "SELECT IFNULL(APPOINTID, 0) from CONSENT_SUBJECT WHERE SAID = "+SAID+" and CONSENTID = "+CONSENTID;
            ResultSet consent_rs = stmt.executeQuery(exist_query);
            int cs_appointid=0;
            while(consent_rs.next()){
                cs_appointid = consent_rs.getInt(1);
            }*/

            // 연구 신청자의 유효 예약(본인확인 안한 예약) 과 지금보다 미래에 있는 예약을 검색
            String exist_query = "select IFNULL(APPOINTID,0) from APPOINTMENT  where SAID ="+SAID + " and IDENTIFYDTC is null and APPOINTDTC >=NOW() ";
            ResultSet exist_rs = stmt.executeQuery(exist_query);
           int APPOINTID = 0;
            while(exist_rs.next()){
                APPOINTID = exist_rs.getInt(1);
            }
            

            if(APPOINTID==0){ // new appointment
                  String insert_action_query = "INSERT INTO APPOINTMENT( SAID, APPOINTDTC) values("+SAID+", '"+VISITDTC+"')";    
                  log("[METORY log]"+"\t||\t[SITEID]="+SITEID+"\t||\t[INVID]="+INVID+"\t||\t[type]="+type+"\t||\t[QUERY]="+insert_action_query.replace("'", "\'"));      
                  stmt.executeUpdate(insert_action_query);   
                    //Get Study ID
                    String get_last_insert = "SELECT LAST_INSERT_ID();";
                    ResultSet rs = stmt.executeQuery(get_last_insert);                    
                    while(rs.next()){
                        APPOINTID = rs.getInt(1);
                    }
                    String update_action_query = "UPDATE CONSENT_SUBJECT SET APPOINTID ="+ APPOINTID +", CS_CONTACT_STAGE=2 WHERE SAID = "+SAID+" and CONSENTID = "+CONSENTID+" and CS_CONTACT_STAGE=1";
                    log("[METORY log]"+"\t||\t[SITEID]="+SITEID+"\t||\t[INVID]="+INVID+"\t||\t[type]="+type+"\t||\t[QUERY]="+update_action_query.replace("'", "\'"));
                    stmt.executeUpdate(update_action_query);   
            } 
            else { //update appointment
                String update_action_query = "UPDATE APPOINTMENT SET APPOINTDTC = '"+VISITDTC+"' WHERE APPOINTID = "+APPOINTID ; 
                log("[METORY log]"+"\t||\t[SITEID]="+SITEID+"\t||\t[INVID]="+INVID+"\t||\t[type]="+type+"\t||\t[QUERY]="+update_action_query.replace("'", "\'"));
                stmt.executeUpdate(update_action_query);   
            }

            String update_sa_query = "UPDATE STUDY_APPLICANT SET SASTAGE =3  WHERE SAID = "+SAID +"  and SASTAGE=2"; 
            log("[METORY log]"+"\t||\t[SITEID]="+SITEID+"\t||\t[INVID]="+INVID+"\t||\t[type]="+type+"\t||\t[QUERY]="+update_sa_query.replace("'", "\'"));
            stmt.executeUpdate(update_sa_query);   

            String applID_query = "select A.APPLID, A.APPLNAME from STUDY_APPLICANT SA, APPLICANT A where SA.APPLID = A.APPLID and SAID=" + SAID ;
            ResultSet applID_rs = stmt.executeQuery(applID_query);
            int APPLID = 0;
            String APPLNAME = "";
            while(applID_rs.next()){
                APPLID = applID_rs.getInt(1);
                APPLNAME = applID_rs.getString(2);
            }     

            stmt.close();
            conn.close();
            out.println(APPLNAME);
        }
          /*v---
       예약 후 문자 메시지에 필요한 정보를 조회
        input: APPOINTID
        return : APPLID, APPLNAME, APPOINTDTC, 실시기관 이름, 실시기관, site context path, applid
        */
         else if(type.equals("GET_MSG_INFO")){
    
            String APPOINTID = request.getParameter("APPOINTID");        
         
            JSONObject info = new JSONObject();

     
            String action_query = "SELECT SAID, DATE_FORMAT(APPOINTDTC,'%Y-%m-%d %H:%i') as APPOINTDTC FROM APPOINTMENT WHERE APPOINTID="+APPOINTID;
            ResultSet rs = stmt.executeQuery(action_query);
            
            int SAID=0;
                    
            while(rs.next()){
                SAID = rs.getInt("SAID");
              
                info.put("APPOINTDTC", rs.getString("APPOINTDTC"));                      
            }

            String appl_query = "SELECT a.APPLNAME,a.APPLID, a.APPLPHONENUM, a.QRCODE FROM APPLICANT a , STUDY_APPLICANT sa WHERE  sa.APPLID=a.APPLID and sa.SAID="+SAID;
            ResultSet appl_rs = stmt.executeQuery(appl_query);
            
           
                    
            while(appl_rs.next()){
               
                info.put("APPLNAME", appl_rs.getString("a.APPLNAME"));     
                info.put("APPLID", appl_rs.getString("a.APPLID"));  
                info.put("APPLPHONE", appl_rs.getString("a.APPLPHONENUM")); 
                 info.put("QRCODE", appl_rs.getString("a.QRCODE")); 
                

            }

            info.put("CONTEXTPATH",request.getContextPath());    
            info.put("SITEIP",siteIp);

            String site_query = "SELECT SITENAME, SITEADDR FROM SITE WHERE   SITEID="+SITEID;
            ResultSet site_rs = stmt.executeQuery(site_query);
            
           
                    
            while(site_rs.next()){
               
                info.put("SITENAME", site_rs.getString("SITENAME"));     
                info.put("SITEADDR", site_rs.getString("SITEADDR"));  
                

            }
    
         ///////////////// 
         //LOG 에 저장
         ///////////////  

            stmt.close();
            conn.close();
           out.println(info);
        }
        /*v---
        연구자가 대상자의 새로운 방문예약을 저장하거나 update한다.
        input: VISITDTC,  SID, APPOINTID, AFID, SAID
        return : APPOINTID       
        */
        else if(type.equals("SAVE_APPOINTDTC")){
            String SAID = request.getParameter("SAID");
            String SID = request.getParameter("SID");
            String APPOINTID = request.getParameter("APPOINTID");
            String VISITTIME = request.getParameter("VISITTIME");
            String VISITDATE = request.getParameter("VISITDATE");
            //String AFID = request.getParameter("AFID");
            String VISITDTC=VISITDATE+" "+ VISITTIME;

             /*int insertnew =0;
            - if(APPOINTID=="" || APPOINTID=="0"||APPOINTID==null   ){
                insertnew =1;
            }else{            //APPOINTID에 해당하는 예약이 유효한지 확인
                String check_appoint_query = "SELECT IFNULL( IDENTIFYDTC, 0) as insertNew FROM  APPOINTMENT WHERE  APPOINTID = "+APPOINTID ; 
                ResultSet check_rs = stmt.executeQuery(check_appoint_query);           
             
                while(check_rs.next()){
                    String result=check_rs.getString("insertNew");
                    if (!result.equals("0")) insertnew=1;
                }
            } */
            // find AFID
            String check_afappoint_query = "SELECT COUNT(AFID), AFID FROM  APPOINT_FIX WHERE  AFDATE='"+VISITDATE+"' and AFTIME"+((VISITTIME.length()>0)? "='"+VISITTIME+"'": " is null") +" and  SID = "+SID ; 
            ResultSet check_af_rs = stmt.executeQuery(check_afappoint_query);           
            int AFID=0;
            while(check_af_rs.next()){
                if(check_af_rs.getInt(1)>0) AFID=check_af_rs.getInt(2);
            }

            if(APPOINTID.equals("0") || APPOINTID.equals("") || APPOINTID==null ) { //insert new
                String insert_action_query = "INSERT INTO APPOINTMENT( SAID, APPOINTDTC, AFID) values("+SAID+", '"+VISITDTC+"',"+AFID+")";
                stmt.executeUpdate(insert_action_query);   
                int insertedAPPOINTID = getLastInsertID(stmt);

                // APPOINTMENT_LOG 저장 - CREATE
                String appointLogPrevQuery = selectPreviousInformation(stmt, "APPOINTMENT_LOG", "APPOINTMENT", tableSchemaName);
                String appointLogInsertquery = appointLogPrevQuery+",'SITE', "+INVID+",'CREATE',NOW() from APPOINTMENT where APPOINTID="+insertedAPPOINTID;
                stmt.executeUpdate(appointLogInsertquery);
            }
            else{
                String update_action_query = "UPDATE APPOINTMENT SET APPOINTDTC = '"+VISITDTC+"', AFID="+AFID+", MEMO=null WHERE APPOINTID = "+APPOINTID ; 
                stmt.executeUpdate(update_action_query);

                // APPOINTMENT_LOG 저장 - UPDATE
                String appointLogPrevQuery = selectPreviousInformation(stmt, "APPOINTMENT_LOG", "APPOINTMENT", tableSchemaName);
                String appointLogInsertquery = appointLogPrevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from APPOINTMENT where APPOINTID="+APPOINTID;
                stmt.executeUpdate(appointLogInsertquery);
            }

            stmt.close();
            conn.close();
        }
        else if (type.equals("GET_STATUS_WITHDRAW_OR_CANCEL")){
            String SAID = request.getParameter("SAID");
            JSONObject jb= new JSONObject();
            //  String query = "select COUNT(CSID) from CONSENT_SUBJECT where  SAID = " + SAID +" and CSCLOSE=1";
            String query = "select COUNT(CSID) , CSID,  CSCLOSE,  CS_CONTACT_STAGE , CS_UNCONTACT_STAGE from CONSENT_SUBJECT where  SAID =" + SAID ;
            ResultSet rs = stmt.executeQuery(query);

            while(rs.next()){
                jb.put("COUNT_CSID", rs.getInt(1));
                jb.put("CSID", rs.getInt(2));
                jb.put("CSCLOSE", rs.getInt(3));
                jb.put(" CS_CONTACT_STAGE", rs.getInt(4));
                jb.put("CS_UNCONTACT_STAGE", rs.getInt(5));              
            }

            String pre_sastage_query = "select SASTAGE from STUDY_APPLICANT  where  SAID = " + SAID ;
            ResultSet rs_sastage = stmt.executeQuery(pre_sastage_query);
          
          
            while(rs_sastage.next()){
                jb.put("SASTAGE", rs_sastage.getInt(1));
            }

            out.println(jb);
             stmt.close();
            conn.close();
      

       }
        else if(type.equals("CHANGE_STATUS")){

            //it is for a researcher to manage an applicant
            // 
            // when status is "종료", 1) Study_applicant table : update CLOSESTAGE=14, 
            //                        2) Consent_Subject table: update CSSTAGE=14, CSSTATUS=8
            // when status is "예약된 대상자",      Consent_Subject table: update CSSTAGE=2, CSSTATUS=2   
            // when status is "임상연구참여불가",   Consent_Subject table: update CSSTAGE=10, CSSTATUS=3
            // when status is "시험참여",   Consent_Subject table: update CSSTAGE=11, CSSTATUS=6
            // when status is "중도탈락",   Consent_Subject table: update CSSTAGE=10, CSSTATUS=7
           
            // else 1) Consent_Subject table: update CSSTATUS

            String SAID = request.getParameter("SAID");
            String STATUS = request.getParameter("status");
            String CONSENTID = request.getParameter("CONSENTID");
            
           // String query = "UPDATE CONSENT_SUBJECT SET CSSTATUS = " + STATUS + " WHERE SAID = "+SAID+" and CONSENTID="+CONSENTID;
           // stmt.executeUpdate(query);
            int SAACTIVE = 1;
          
             DecimalFormat df = new DecimalFormat("00");
                Calendar calendar = Calendar.getInstance();
                String year = Integer.toString(calendar.get(Calendar.YEAR)); 
                String month = df.format(calendar.get(Calendar.MONTH) + 1); 
                String day = df.format(calendar.get(Calendar.DATE)); 
                String hour = df.format(calendar.get(Calendar.HOUR_OF_DAY));
                String minute = df.format(calendar.get(Calendar.MINUTE));
                String second = df.format(calendar.get(Calendar.SECOND));
            String    today = year+"-"+month+"-"+day+" "+hour+":"+minute+":"+second;

            if(Integer.parseInt(STATUS)>=5){
               
                SAACTIVE = 0;
               
            }

            JSONObject data = new JSONObject();
            String result="";
            int sid=0;  
            String get_appl_info_query = "select  a.APPLID , a.APPLPHONENUM, a.APPLNAME,sa.SID from STUDY_APPLICANT sa, APPLICANT a   where sa.APPLID=a.APPLID and sa.SAID = " + SAID;
            ResultSet get_appl_info_rs = stmt.executeQuery(get_appl_info_query);
            while(get_appl_info_rs.next()){    
                data.put("APPLID", get_appl_info_rs.getInt(1));
                data.put("APPLPHONENUM", get_appl_info_rs.getString(2));
                data.put("APPLNAME", get_appl_info_rs.getString(3));
                sid=get_appl_info_rs.getInt("sa.SID") ;
            }
            int sastage=0;
            try{
                sastage=Integer.parseInt(STATUS);
            }catch(Exception e){

            }
           
            /* if(sastage==8){ //save to bc 동의철회           


                String study_bc_query="SELECT spon.SPONSORNAME, s.PRTNO, s.BCCHANNEL  from SPONSOR spon, study s where s.SPONSORID=spon.SPONSORID and s.SID="+sid;
                ResultSet study_bc_rs = stmt.executeQuery(study_bc_query);      
                String sponsorname="";
                String prtno="";
                String channel="";
                while(study_bc_rs.next()){
                    sponsorname=study_bc_rs.getString("spon.SPONSORNAME");
                    prtno=study_bc_rs.getString("s.PRTNO");
                    channel=study_bc_rs.getString("s.BCCHANNEL");          
                }
                String consent_query="SELECT CVERSION, CFILE_HASH from CONSENT where CONSENTID="+CONSENTID;
                ResultSet consent_rs = stmt.executeQuery(consent_query);      
                String cversion="";
                String cfile_hash="";
                
                while(consent_rs.next()){
                    cversion=consent_rs.getString("CVERSION");
                    cfile_hash=consent_rs.getString("CFILE_HASH");          
                }
                //ConsentWidraw(channel_name, user_id, consent_idx, site_id, protocol_no, sponsor_id, subject_id, consent_version, consent_hash, withdraw_time);      	JbcpBCRequest BCobj = new JbcpBCRequest(dAppIp+"/api/consent/withdraw");
                
                String consent_idx= SITENAME + "consent_" + CONSENTID + "_s" + SAID;          
                JbcpBCRequest BCobj = new JbcpBCRequest(dAppIp);
                
                result=BCobj.ConsentWithdraw(channel,INVMAIL,consent_idx, SITENAME, prtno,sponsorname, SAID, cversion, cfile_hash, today);
            
                if(result.equals("ok")){//동의철회인 경우 result가 ok 인 경우에만 crcp에 저장
                    //save to crcp
                    String query ="UPDATE STUDY_APPLICANT SET SASTAGE  = " + STATUS+ ", SAACTIVE="+SAACTIVE+", SACLOSEDTC='"+today+"' WHERE SAID = "+SAID;
                    stmt.executeUpdate(query);  

                    log("[METORY log]"+"\t||\t[SITEID]="+SITEID+"\t||\t[INVID]="+INVID+"\t||\t[type]="+type+"\t||\t[QUERY]="+query.replace("'", "\'"));
                }
                data.put("RESULT", result);
            }
            else  */
            if(sastage==1){//신청으로 다시 돌아간 경우
                //save to crcp
                String query ="UPDATE STUDY_APPLICANT SET SASTAGE  = " + STATUS+ ", SAACTIVE=1, SACLOSEDTC=null WHERE SAID = "+SAID;
                stmt.executeUpdate(query);
                
                //STUDY_APPLICANT_LOG 저장
                String studyApplicantLogPrevQuery = selectPreviousInformation(stmt, "STUDY_APPLICANT_LOG", "STUDY_APPLICANT", tableSchemaName);
                String studyApplicantLogInsertquery = studyApplicantLogPrevQuery+",'SITE', "+INVID+",'UPDATE', NOW() from STUDY_APPLICANT where SAID="+SAID;
                stmt.executeUpdate(studyApplicantLogInsertquery);

            }else {//STATUS=6,7,9 연구종료, 탈락, 신청취소인경우
                //save to crcp
                String query ="UPDATE STUDY_APPLICANT SET SASTAGE  = " + STATUS+ ", SAACTIVE="+SAACTIVE+", SACLOSEDTC='"+today+"' WHERE SAID = "+SAID;
                stmt.executeUpdate(query);

                // STUDY_APPLICANT_LOG 저장 - UPDATE
                String studyApplicantLogPrevQuery = selectPreviousInformation(stmt, "STUDY_APPLICANT_LOG", "STUDY_APPLICANT", tableSchemaName);
                String studyApplicantLogInsertquery = studyApplicantLogPrevQuery+",'SITE', "+INVID+",'UPDATE', NOW() from STUDY_APPLICANT where SAID="+SAID;
                stmt.executeUpdate(studyApplicantLogInsertquery);

            /* switch(STATUS){
                    case "1": //신청
                        status_query = "UPDATE STUDY_APPLICANT SET SASTAGE  = " + STATUS+ " WHERE SAID = "+SAID;
                    break;

                    case "4": //예약된 대상자
                        //status_query = "UPDATE STUDY_APPLICANT SET SASTAGE  = " + STATUS+ " WHERE SAID = "+SAID;
                    break;

                    case "5": //본인확인
                    // status_query = "_SUBJECT SET CSSTAGE = 10,  CSSTATUS = " + STATUS+ " WHERE SAID = "+SAID+" and CONSENTID="+CONSENTID;
                    //  query = "UPDATE STUDY_APPLICANT SET CLOSESTAGE = 10 WHERE SAID = "+SAID;
                    break;

                    case "6": //연구종료
                        status_query = "UPDATE CONSENT_SUBJECT SET CSSTAGE = 11 ,  CSSTATUS = " + STATUS+ " WHERE SAID = "+SAID+" and CONSENTID="+CONSENTID;
                    
                    break;

                    case "7": //중도탈락
                        status_query = "UPDATE CONSENT_SUBJECT SET CSSTAGE = 10 ,  CSSTATUS = " + STATUS+ " WHERE SAID = "+SAID+" and CONSENTID="+CONSENTID;
                        query = "UPDATE STUDY_APPLICANT SET CLOSESTAGE = 10 WHERE SAID = "+SAID;
                    break;

                    case "8": //동의철회
                        status_query = "UPDATE CONSENT_SUBJECT SET CSSTAGE = 14 ,  CSSTATUS = " + STATUS+ " WHERE SAID = "+SAID+" and CONSENTID="+CONSENTID;
                        query = "UPDATE STUDY_APPLICANT SET CLOSESTAGE = 14 WHERE SAID = "+SAID;                   
                        break;

                case "9": //신청취소
                        status_query = "UPDATE CONSENT_SUBJECT SET CSSTAGE = 14 ,  CSSTATUS = " + STATUS+ " WHERE SAID = "+SAID+" and CONSENTID="+CONSENTID;
                        query = "UPDATE STUDY_APPLICANT SET CLOSESTAGE = 14 WHERE SAID = "+SAID;                   
                        break;
                    default : 
                        status_query ="UPDATE CONSENT_SUBJECT SET CSSTATUS = " + STATUS + " WHERE SAID = "+SAID+" and CONSENTID="+CONSENTID;
                    break;
                } */
            }
            out.println(data);
            stmt.close();  
            conn.close();
        }
     else if(type.equals("WITHDRAW")){// 동의철회

            //it is for a researcher to manage an applicant
            // 
            // when status is "종료", 1) Study_applicant table : update CLOSESTAGE=14, 
            //                        2) Consent_Subject table: update CSSTAGE=14, CSSTATUS=8
            // when status is "예약된 대상자",      Consent_Subject table: update CSSTAGE=2, CSSTATUS=2   
            // when status is "임상연구참여불가",   Consent_Subject table: update CSSTAGE=10, CSSTATUS=3
            // when status is "시험참여",   Consent_Subject table: update CSSTAGE=11, CSSTATUS=6
            // when status is "중도탈락",   Consent_Subject table: update CSSTAGE=10, CSSTATUS=7
           
            // else 1) Consent_Subject table: update CSSTATUS
            String STATUS="8";
            String SAID = request.getParameter("SAID");         
            String CONSENTID = request.getParameter("CONSENTID");
            
           // String query = "UPDATE CONSENT_SUBJECT SET CSSTATUS = " + STATUS + " WHERE SAID = "+SAID+" and CONSENTID="+CONSENTID;
           // stmt.executeUpdate(query);
            int SAACTIVE = 0;

                DecimalFormat df = new DecimalFormat("00");
                Calendar calendar = Calendar.getInstance();
                String year = Integer.toString(calendar.get(Calendar.YEAR)); 
                String month = df.format(calendar.get(Calendar.MONTH) + 1); 
                String day = df.format(calendar.get(Calendar.DATE)); 
                String hour = df.format(calendar.get(Calendar.HOUR_OF_DAY));
                String minute = df.format(calendar.get(Calendar.MINUTE));
                String second = df.format(calendar.get(Calendar.SECOND));
            String    today = year+"-"+month+"-"+day+" "+hour+":"+minute+":"+second;
            JSONArray data_arr = new JSONArray();
            JSONObject data = new JSONObject();
            String result="";
            int sid=0;  
            String get_appl_info_query = "select  a.APPLID , a.APPLPHONENUM, a.APPLNAME,sa.SID from STUDY_APPLICANT sa, APPLICANT a   where sa.APPLID=a.APPLID and sa.SAID = " + SAID;
            ResultSet get_appl_info_rs = stmt.executeQuery(get_appl_info_query);
            while(get_appl_info_rs.next()){    
                data.put("APPLID", get_appl_info_rs.getInt(1));
                data.put("APPLPHONENUM", get_appl_info_rs.getString(2));
                data.put("APPLNAME", get_appl_info_rs.getString(3));
                sid=get_appl_info_rs.getInt("sa.SID") ;
            }
         
            //BC 저장 동의철회

                String study_bc_query="SELECT spon.SPONSORNAME, s.PRTNO, s.BCCHANNEL  from SPONSOR spon, study s where s.SPONSORID=spon.SPONSORID and s.SID="+sid;
                ResultSet study_bc_rs = stmt.executeQuery(study_bc_query);      
                String sponsorname="";
                String prtno="";
                String channel="";
                while(study_bc_rs.next()){
                    sponsorname=study_bc_rs.getString("spon.SPONSORNAME");
                    prtno=study_bc_rs.getString("s.PRTNO");
                    channel=study_bc_rs.getString("s.BCCHANNEL");          
                }
                String consent_query="SELECT CVERSION, CFILE_HASH from CONSENT where CONSENTID="+CONSENTID;
                ResultSet consent_rs = stmt.executeQuery(consent_query);      
                String cversion="";
                String cfile_hash="";
                
                while(consent_rs.next()){
                    cversion=consent_rs.getString("CVERSION");
                    cfile_hash=consent_rs.getString("CFILE_HASH");          
                }
                //ConsentWidraw(channel_name, user_id, consent_idx, site_id, protocol_no, sponsor_id, subject_id, consent_version, consent_hash, withdraw_time);      	JbcpBCRequest BCobj = new JbcpBCRequest(dAppIp+"/api/consent/withdraw");
                
                String consent_idx= SITENAME + "consent_" + CONSENTID + "_s" + SAID;          
                JbcpBCRequest BCobj = new JbcpBCRequest(dAppIp);
                
                result=BCobj.ConsentWithdraw(channel,INVMAIL,consent_idx, SITENAME, prtno,sponsorname, SAID, cversion, cfile_hash, today);
            
                if(result.equals("ok")){//동의철회인 경우 result가 ok 인 경우에만 crcp에 저장              
                    String query ="UPDATE STUDY_APPLICANT SET SASTAGE  = " + STATUS+ ", SAACTIVE="+SAACTIVE+", SACLOSEDTC='"+today+"' WHERE SAID = "+SAID;
                    stmt.executeUpdate(query);  

                    log("[METORY log]"+"\t||\t[SITEID]="+SITEID+"\t||\t[INVID]="+INVID+"\t||\t[type]="+type+"\t||\t[QUERY]="+query.replace("'", "\'"));
                }
                data.put("RESULT", result);
           data_arr.add(data);
            out.println(data_arr);
            stmt.close();  
            conn.close();
        }
        /*
        * 해당연구에서 대상자 한명의 모든 동의기록 조회
        * 입력: SAID
        */
        else if(type.equals("LOAD_APPL_ALL_CONSENT")){
            String SAID = request.getParameter("SAID");
            String SID = request.getParameter("SID");
           
            
                String query = "select c.CONSENTID, cs.CSID, c.CSGRPID, c.CVERSION, c.CFILE, c.CFILENAME, IFNULL(cs.SUBJ_SIGNDTC,'-'),IFNULL(cs.LAR_SIGNDTC,'-') ,IFNULL(cs.INV_SIGNDTC,'-') , g.CSGRPTITLE , g.CSGRPTYPE FROM CONSENT_SUBJECT cs, CONSENT c, CONSENT_GROUP g WHERE c.CONSENTID=cs.CONSENTID and cs.SAID="+SAID+" and g.CSGRPID=c.CSGRPID GROUP BY c.CSGRPID, c.CONSENTID order by c.CPUBLISHDTC desc";

                ResultSet rs = stmt.executeQuery(query);
                JSONArray consents = new JSONArray();
              
                while(rs.next()){
                    JSONObject consent = new JSONObject();
                    consent.put("CONSENTID", rs.getInt(1));
                    consent.put("CSID", rs.getInt(2));
                    consent.put("CSGRPID", rs.getInt(3));
                    consent.put("CVERSION", rs.getString(4));
                    consent.put("CFILE", rs.getString(5));
                    consent.put("CFILENAME", rs.getString(6));
                    consent.put("CONTEXTPATH", request.getContextPath());
                    consent.put("SIGNDTC", rs.getString(7));
                    consent.put("LAR_SIGNDTC", rs.getString(8));
                    consent.put("INV_SIGNDTC", rs.getString(9));  
                    
                    
                        consent.put("CSGRPTITLE", rs.getString(10));  
                        consent.put("CSGRPTYPE", rs.getInt(11));       
                    
                    consents.add(consent);

                }
             
                stmt.close();
                conn.close();
                out.println(consents);
      
        }
        else if(type.equals("load_consent_group_list")){
            String SID = request.getParameter("SID");
           
            String query = "SELECT CSGRPTITLE FROM CONSENT_GROUP WHERE SID="+ SID + "   and SITEID="+SITEID;
        //  else if(STUDYORDER.equals("CREATEDTC")) query = "SELECT SID, TITLE,SAPPL, SSEX,SNUM,STARGET,SDATE,ORDERS, SITEID FROM STUDY WHERE SPUBLISHED = 1 ORDER BY ORDERS DESC, SCREATEDTC= "+ORDERS;
            ResultSet rs = stmt.executeQuery(query);

            JSONArray consentgroups = new JSONArray();

            while(rs.next()){
                JSONObject consentgroup = new JSONObject();
                consentgroup.put("GROUPNAME", rs.getString(1));
                consentgroups.add(consentgroup);
            }
            stmt.close();
            conn.close();
            out.println(consentgroups);
        }
         else if(type.equals("load_appl_info")){
             
            JSONArray applicants = new JSONArray();

            //Load Study information
            String SAID = request.getParameter("SAID");
            String SID = request.getParameter("SID");
            //get applicant info
            String query = "select a.APPLID,  a.APPLNAME, a.APPLMAIL, a.APPLPHONENUM, a.APPLBRTHDTC, a.APPLSEX,  sa.APPLDTC, sa.SASTAGE, a.height_cm, a.weight_kg from study_applicant sa , APPLICANT a where a.APPLID = sa.APPLID  and sa.SAID= "+SAID;
            ResultSet rs = stmt.executeQuery(query);

            while(rs.next()){
                JSONObject applicant = new JSONObject();
                applicant.put("APPLID", rs.getInt(1));
                applicant.put("APPLNAME", rs.getString(2));
                applicant.put("APPLMAIL", rs.getString(3));
                applicant.put("APPLPHONENUM", rs.getString(4));
                applicant.put("APPLBRTHDTC", rs.getString(5));
                applicant.put("APPLSEX", rs.getInt(6));
                applicant.put("APPLDTC", rs.getString(7));
              //  applicant.put("VISITDTC", rs.getString(8));
                applicant.put("SASTAGE", rs.getInt(8));
                applicant.put("HEIGHT", rs.getDouble("a.height_cm"));
                applicant.put("WEIGHT", rs.getDouble("a.weight_kg"));
                //get study info
                Statement stmt_study = conn.createStatement();
                try{
                    String search_query = "SELECT s.PRTNO,  si.INVID, si.SIROLETITLE, si.SIROLECODE, i.INVNAME FROM STUDY_INV si , INVESTIGATOR i, STUDY s WHERE si.SID=s.SID and si.SID = " + SID +" and si.INVID= i.INVID and i.SITEID="+SITEID + " and  si.SIROLECODE=1";
                    ResultSet rs_query = stmt_study.executeQuery(search_query);
                    while(rs_query.next()){
                        applicant.put("PRTNO", rs_query.getString(1));  
                        applicant.put("PIID", rs_query.getInt(2));  
                        applicant.put("PINAME", rs_query.getString(5));  
                    }
                    stmt_study.close();
                }catch(Exception  e){
                    stmt_study.close();
                }
                finally{
                    if(stmt_study!=null)   stmt_study.close();
                }

                applicants.add(applicant);
            }

            stmt.close();
            conn.close();
            out.println(applicants);

        }


        /* 연구자가 한 대상자의 설명요청 버튼 클릭
        * 입력: SAID, CONSENTID, NOWDTC
        */
        else if(type.equals("add_request")){
            String SAID = request.getParameter("SAID");       
            String CONSENTID = request.getParameter("CONSENTID");  
            String NOWDTC = request.getParameter("NOWDTC");   

            String CSquery = "UPDATE consent_subject set CS_CONTACT_STAGE =4 , CSREQUESTDTC = '"+NOWDTC+"' WHERE SAID= "+SAID+" and CONSENTID ="+CONSENTID ;
            stmt.executeUpdate(CSquery);

            // CONSENT_SUBJECT_LOG 저장 - UPDATE
            String consentSubjectLogPrevQuery = selectPreviousInformation(stmt, "CONSENT_SUBJECT_LOG", "CONSENT_SUBJECT", tableSchemaName);
            String consentSubjectLogInsertquery = consentSubjectLogPrevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from CONSENT_SUBJECT where SAID="+SAID+" and CONSENTID="+CONSENTID;
            stmt.executeUpdate(consentSubjectLogInsertquery);

            stmt.close();
            conn.close();
            out.println(SAID);
      
        }

        /* 연구자가 한 대상자의 설명요청  취소
        * 입력: SAID, CONSENTID, 
        */
        else if(type.equals("cancel_request")){
            String SAID = request.getParameter("SAID");       
            String CONSENTID = request.getParameter("CONSENTID");  
            String NOWDTC = request.getParameter("NOWDTC");   

            String CSquery = "UPDATE consent_subject set CS_CONTACT_STAGE =3 , CSREQUESTDTC = null WHERE SAID= "+SAID+" and CONSENTID ="+CONSENTID + " and CS_CONTACT_STAGE=4";
            stmt.executeUpdate(CSquery);
            
            // CONSENT_SUBJECT_LOG 작성 - UPDATE
            String consentSubjectLogPrevQuery = selectPreviousInformation(stmt, "CONSENT_SUBJECT_LOG", "CONSENT_SUBJECT", tableSchemaName);
            String consentSubjectLogInsertquery = consentSubjectLogPrevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from CONSENT_SUBJECT where SAID="+SAID+" and CONSENTID="+CONSENTID+" and CS_CONTACT_STAGE=3";
            stmt.executeUpdate(consentSubjectLogInsertquery); 

            stmt.close();
            conn.close();
            out.println(SAID);
      
        }

         /* 연구자가 한 대상자의 설명시작  취소
        * 입력: SAID, CONSENTID, CONTACT_COPTION
        */
        else if(type.equals("cancel_start")){
            String SAID = request.getParameter("SAID");       
            String CONSENTID = request.getParameter("CONSENTID");  
            String CONTACT_COPTION = request.getParameter("CONTACT_COPTION");   

            int contact_stage=4;
            int uncontact_stage=1;
           
            String CSquery ="";
            String consentSubjectLogPrevQuery = selectPreviousInformation(stmt, "CONSENT_SUBJECT_LOG", "CONSENT_SUBJECT", tableSchemaName);
            String consentSubjectLogInsertQuery = "";
            if (Integer.parseInt(CONTACT_COPTION)==1) {//대면
                CSquery = "UPDATE consent_subject set CS_CONTACT_STAGE ="+contact_stage+ ", CSSTARTDTC = null WHERE SAID= "+SAID+" and CONSENTID ="+CONSENTID + " and CS_CONTACT_STAGE="+(contact_stage+1);
                consentSubjectLogInsertQuery = consentSubjectLogPrevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from CONSENT_SUBJECT where SAID="+SAID+" and CONSENTID="+CONSENTID+" and CS_CONTACT_STAGE="+contact_stage;
            }else  {//비대면
                CSquery = "UPDATE consent_subject set CS_UNCONTACT_STAGE ="+uncontact_stage+ ", CSSTARTDTC = null WHERE SAID= "+SAID+" and CONSENTID ="+CONSENTID;// + " and CS_UNCONTACT_STAGE="+(uncontact_stage+1);
                consentSubjectLogInsertQuery = consentSubjectLogPrevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from CONSENT_SUBJECT where SAID="+SAID+" and CONSENTID="+CONSENTID+" and CS_UNCONTACT_STAGE="+uncontact_stage;
            }
            stmt.executeUpdate(CSquery);

            // CONSENT_SUBJECT_LOG 작성
            stmt.executeUpdate(consentSubjectLogInsertQuery);

            stmt.close();
            conn.close();
            out.println(SAID);
      
        }
        
        /* 연구자가 한 대상자의 설명종료  취소
        * 입력: SAID, CONSENTID, 
        */
        else if(type.equals("cancel_end")){
            String SAID = request.getParameter("SAID");       
            String CONSENTID = request.getParameter("CONSENTID");  
            String CONTACT_COPTION = request.getParameter("CONTACT_COPTION"); 

            int contact_stage=5;
            int uncontact_stage=2;
           
            String CSquery ="";
            String consentSubjectLogPrevQuery = selectPreviousInformation(stmt, "CONSENT_SUBJECT_LOG", "CONSENT_SUBJECT", tableSchemaName);
            String consentSubjectLogInsertquery = consentSubjectLogPrevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from CONSENT_SUBJECT WHERE SAID= "+SAID+" and CONSENTID="+CONSENTID + " and CS_UNCONTACT_STAGE="+uncontact_stage;
            if (Integer.parseInt(CONTACT_COPTION)==1) {//대면
                CSquery = "UPDATE consent_subject set CS_CONTACT_STAGE ="+contact_stage+ ", CSENDDTC = null WHERE SAID= "+SAID+" and CONSENTID ="+CONSENTID + " and CS_CONTACT_STAGE="+(contact_stage+1);
                consentSubjectLogInsertquery = consentSubjectLogPrevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from CONSENT_SUBJECT WHERE SAID= "+SAID+" and CONSENTID ="+CONSENTID + " and CS_CONTACT_STAGE="+contact_stage;
            }else  {//비대면
                CSquery = "UPDATE consent_subject set CS_UNCONTACT_STAGE ="+uncontact_stage+ ", CSENDDTC = null WHERE SAID= "+SAID+" and CONSENTID ="+CONSENTID ;//+ " and CS_UNCONTACT_STAGE="+(uncontact_stage+1);
                consentSubjectLogInsertquery = consentSubjectLogPrevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from CONSENT_SUBJECT WHERE SAID= "+SAID+" and CONSENTID="+CONSENTID + " and CS_UNCONTACT_STAGE="+uncontact_stage;
            }
            stmt.executeUpdate(CSquery);

            // CONSENT_SUBJECT_LOG 저장 - UPDATE
            stmt.executeUpdate(consentSubjectLogInsertquery);

            stmt.close();
            conn.close();
            out.println(SAID);
      
        }
        /* 연구자가 한 대상자의 서명 기록  취소
        * 입력: SAID, CONSENTID, 
        */
        else if(type.equals("cancel_sign")){
            String SAID = request.getParameter("SAID");       
            String CONSENTID = request.getParameter("CONSENTID");  
            String CONTACT_COPTION = request.getParameter("CONTACT_COPTION"); 

            int contact_stage=6;
            int uncontact_stage=2; //설명시작단계
           
            String CSquery ="";
            String consentSubjectLogPrevQuery = selectPreviousInformation(stmt, "CONSENT_SUBJECT_LOG", "CONSENT_SUBJECT", tableSchemaName);
            String consentSubjectLogInsertquery = consentSubjectLogPrevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from CONSENT_SUBJECT WHERE SAID= "+SAID+" and CONSENTID="+CONSENTID + " and CS_UNCONTACT_STAGE="+uncontact_stage;
            if (Integer.parseInt(CONTACT_COPTION)==1) {//대면
                CSquery = "UPDATE consent_subject set CS_CONTACT_STAGE ="+contact_stage+ ",SUBJ_SIGN_NAME =null, SUBJ_SIGN=null, SUBJ_SIGNDTC = null WHERE SAID= "+SAID+" and CONSENTID ="+CONSENTID + " and CS_CONTACT_STAGE="+(contact_stage+1);
                consentSubjectLogInsertquery = consentSubjectLogPrevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from CONSENT_SUBJECT WHERE SAID= "+SAID+" and CONSENTID ="+CONSENTID +" and CS_CONTACT_STAGE="+contact_stage;
            }else  {//비대면
                CSquery = "UPDATE consent_subject set CS_UNCONTACT_STAGE ="+uncontact_stage+ ",SUBJ_SIGN_NAME =null, SUBJ_SIGN=null, SUBJ_SIGNDTC = null , CSCLOSE=0 WHERE SAID= "+SAID+" and CONSENTID ="+CONSENTID ;
                consentSubjectLogInsertquery = consentSubjectLogPrevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from CONSENT_SUBJECT WHERE SAID= "+SAID+" and CONSENTID ="+CONSENTID+" and CS_UNCONTACT_STAGE ="+uncontact_stage;
            }

            stmt.executeUpdate(CSquery);
            stmt.executeUpdate(consentSubjectLogInsertquery); 
            //log 로그 테이블 : WHO, WHERE(site url), WHEN, WHAT(.... 정의해야함)

            stmt.close();
            conn.close();
            out.println(SAID);
      
        }
         /* 연구자가 한 대상자의 연구자 서명 기록  취소
        * 입력: SAID, CONSENTID, 
        */
        else if(type.equals("cancel_invsign")){
            String SAID = request.getParameter("SAID");       
            String CONSENTID = request.getParameter("CONSENTID");  
            String CONTACT_COPTION = request.getParameter("CONTACT_COPTION"); 
            //String INV_SIGN_COPTION = request.getParameter("INV_SIGN_COPTION");  
            int contact_stage=7;
            int uncontact_stage=5; //서명하려면 econsent에서 본인확인해야함
           
            String CSquery = "";
            String consentSubjectLogPrevQuery = selectPreviousInformation(stmt, "CONSENT_SUBJECT_LOG", "CONSENT_SUBJECT", tableSchemaName);
            String consentSubjectLogInsertquery = "";
            if (Integer.parseInt(CONTACT_COPTION)==1) {//대면
                CSquery = "UPDATE consent_subject set CS_CONTACT_STAGE ="+contact_stage+ ",CSCLOSE=0, INVID=null, INV_SIGN_NAME=null, INV_SIGNDTC = null WHERE SAID= "+SAID+" and CONSENTID ="+CONSENTID + " and CS_CONTACT_STAGE="+(contact_stage+1);
                consentSubjectLogInsertquery = consentSubjectLogPrevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from CONSENT_SUBJECT WHERE SAID= "+SAID+" and CONSENTID ="+CONSENTID + " and CS_CONTACT_STAGE="+contact_stage;
            }else  {//비대면
                CSquery = "UPDATE consent_subject set CS_UNCONTACT_STAGE ="+uncontact_stage+ ",CSCLOSE=0, INVID=null, INV_SIGN_NAME=null, INV_SIGNDTC = null WHERE SAID= "+SAID+" and CONSENTID ="+CONSENTID ;//+ " and CS_UNCONTACT_STAGE="+(uncontact_stage+1);      
                consentSubjectLogInsertquery = consentSubjectLogPrevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from CONSENT_SUBJECT WHERE SAID= "+SAID+" and CONSENTID ="+CONSENTID + " and CS_UNCONTACT_STAGE ="+uncontact_stage;
            }
            stmt.executeUpdate(CSquery);  
            
            // CONSENT_SUBJECT_LOG 저장 - UPDATE
            stmt.executeUpdate(consentSubjectLogInsertquery);
           
            stmt.close();
            conn.close();
            out.println(SAID);
      
        }
        else if(type.equals("load_consent_group_list")){
            String SID = request.getParameter("SID");
            
            String query = "SELECT CSGRPTITLE FROM CONSENT_GROUP WHERE SID="+ SID + "   and SITEID="+SITEID;
        //  else if(STUDYORDER.equals("CREATEDTC")) query = "SELECT SID, TITLE,SAPPL, SSEX,SNUM,STARGET,SDATE,ORDERS, SITEID FROM STUDY WHERE SPUBLISHED = 1 ORDER BY ORDERS DESC, SCREATEDTC= "+ORDERS;
            ResultSet rs = stmt.executeQuery(query);

            JSONArray consentgroups = new JSONArray();

            while(rs.next()){
                JSONObject consentgroup = new JSONObject();
                consentgroup.put("GROUPNAME", rs.getString(1));
                consentgroups.add(consentgroup);
            }
            stmt.close();
            conn.close();
            out.println(consentgroups);
        }
          /*//예약일 필터를 위해 리스트 조회
           else if(type.equals("load_appoint_list")){
            String SID = request.getParameter("SID");
            String query =  "SELECT  sa.SAID from APPOINTMENT a, STUDY_APPLICANT sa where sa.SAID=a.SAID and sa.SID="+SID+" and sa.SASTAGE not in (9) group by sa.SAID desc";
        //  else if(STUDYORDER.equals("CREATEDTC")) query = "SELECT SID, TITLE,SAPPL, SSEX,SNUM,STARGET,SDATE,ORDERS, SITEID FROM STUDY WHERE SPUBLISHED = 1 ORDER BY ORDERS DESC, SCREATEDTC= "+ORDERS;
            ResultSet rs = stmt.executeQuery(query);

            JSONArray sites = new JSONArray();

            while(rs.next()){
                JSONObject site = new JSONObject();
                site.put("APPOINTDTC", rs.getString(1));
                sites.add(site);
            }
            stmt.close();
            conn.close();
            out.println(sites);
        }*/

         /*
            신청취소를 한 대상자를 제외한 연구에 해당하는 모든 자원자들의 SASTAGE 와 예약 정보 보기
        */
        else if(type.equals("check_subject_joined")){
             JSONObject applicant = new JSONObject();

            //Load Study information
           
            String APPLNAME =request.getParameter("APPLNAME");    
            String APPLBRTHDTC = request.getParameter("APPLBIRTH");
            String APPLSEX = request.getParameter("APPLSEX");
  

            String exist_query ="select count(applid), IFNULL(applmail,'') from APPLICANT where APPLNAME ='" + APPLNAME+"' and APPLBRTHDTC='"+APPLBRTHDTC+"' and APPLSEX="+APPLSEX;
                // String exist_query = "select EXISTS (select * from APPLICANT where APPLNAME = '" + APPLNAME+"', APPLBRTHDTC='"+APPLBIRTHDTC+"',APPLSEX="APPLSEX+") as success;";
            ResultSet exist_rs = stmt.executeQuery(exist_query);
            int exist = 0;
            String result="";
            while(exist_rs.next()){
                exist = exist_rs.getInt(1);
                applicant.put("result", exist);
                applicant.put("email",  exist_rs.getString(2));
                                       
            } 
       
            stmt.close();
            conn.close();
            out.println(applicant);
        }
        else if(type.equals("check_email")){
            JSONObject resultJsonObject = new JSONObject();
            String APPLMAIL = request.getParameter("APPLMAIL");

            String duplicateCheckQuery = "select count(APPLMAIL) from APPLICANT where APPLMAIL='"+APPLMAIL+"'";
            ResultSet rs = stmt.executeQuery(duplicateCheckQuery);
            while(rs.next()){
                resultJsonObject.put("result", rs.getInt(1));
            }

            stmt.close();
            conn.close();
            out.println(resultJsonObject);
        }
        else if(type.equals("add_subject")){
 
            String APPLPWD = URLDecoder.decode(request.getParameter("APPLPWD"), "UTF-8");
            String APPLNAME =URLDecoder.decode(request.getParameter("APPLNAME"), "UTF-8");
            String APPLMAIL = URLDecoder.decode(request.getParameter("APPLMAIL"), "UTF-8");
            String APPLPHONENUM = URLDecoder.decode(request.getParameter("APPLPHONE"), "UTF-8");
            String APPLBRTHDTC = URLDecoder.decode(request.getParameter("APPLBIRTH"), "UTF-8");
            String APPLSEX = URLDecoder.decode(request.getParameter("APPLSEX"), "UTF-8");
            String SID = request.getParameter("SID");

    
            DecimalFormat df = new DecimalFormat("00");
            Calendar calendar = Calendar.getInstance();
            String year = Integer.toString(calendar.get(Calendar.YEAR)); 
            String month = df.format(calendar.get(Calendar.MONTH) + 1); 
            String day = df.format(calendar.get(Calendar.DATE)); 
            String hour = df.format(calendar.get(Calendar.HOUR_OF_DAY));
            String minute = df.format(calendar.get(Calendar.MINUTE));
            String second = df.format(calendar.get(Calendar.SECOND));    
            String today = year+"-"+month+"-"+day+" "+hour+":"+minute+":"+second;
    
            
            String insert_query = "INSERT INTO APPLICANT(  APPLNAME, APPLMAIL, APPLPHONENUM, APPLBRTHDTC, APPLSEX, APPLDATE, APPLPWD, PASS) values( '"+APPLNAME+"', '"+APPLMAIL+"', '"+APPLPHONENUM+"', '"+APPLBRTHDTC+"', "+APPLSEX+", '"+today+"', '"+APPLPWD+"', 2)";
            stmt.executeUpdate(insert_query);
            int APPLID = getLastInsertID(stmt);

            // APPLICANT_LOG 저장 - CREATE
            String applicantLogPrevQuery = selectPreviousInformation(stmt, "APPLICANT_LOG", "APPLICANT", tableSchemaName);
            String applicantLogInsertquery = applicantLogPrevQuery+",'SITE', "+INVID+",'CREATE',NOW() from APPLICANT where APPLID="+APPLID;
            stmt.executeUpdate(applicantLogInsertquery);
    
            ////create QRCODE   
            String str="APPLID = " + APPLID +" and APPLDATE="+today;
            //Convert string to bytes
            byte bytes[] = str.getBytes();            
            Checksum checksum = new Adler32();         
            checksum.update(bytes,0,bytes.length);
            long lngChecksum = checksum.getValue();
            String qrcode=String.valueOf(lngChecksum);
            ////END QRCODE    
        
            String update_appl_query = "UPDATE APPLICANT SET QRCODE= '"+qrcode+"' WHERE APPLID = "+APPLID;
            stmt.executeUpdate(update_appl_query);

            // APPLICANT_LOG 저장 - UPDATE
            applicantLogPrevQuery = selectPreviousInformation(stmt, "APPLICANT_LOG", "APPLICANT", tableSchemaName);
            applicantLogInsertquery = applicantLogPrevQuery+",'SITE', "+INVID+",'UPDATE', NOW() from APPLICANT where APPLID="+APPLID;
            stmt.executeUpdate(applicantLogInsertquery);

            /*- String search_query = "SELECT SITEID FROM STUDY WHERE SID = "+SID+";";
            ResultSet search_rs = stmt.executeQuery(search_query);
            int SITEID = 0;
            while(search_rs.next()){
                SITEID = search_rs.getInt(1);
            }   */

            //연구에 new 지원자 저장
            String insert_appl_query = "INSERT INTO STUDY_APPLICANT(SITEID, SID, APPLID, APPLDTC) values("+SITEID+", "+SID+", "+APPLID+", '"+today+"')";
            stmt.executeUpdate(insert_appl_query);            
            int SAID = getLastInsertID(stmt);

            // STUDY_APPLICANT_LOG - CREATE
            String studyApplicantLogPrevQuery = selectPreviousInformation(stmt, "STUDY_APPLICANT_LOG", "STUDY_APPLICANT", tableSchemaName);
            String studyApplicantLogInsertquery = studyApplicantLogPrevQuery+",'SITE', "+INVID+",'CREATE',NOW() from STUDY_APPLICANT where SAID="+SAID;
            stmt.executeUpdate(studyApplicantLogInsertquery);

            //유효한 최종 동의서를 찾아 CS테이블에 저장
            String consent_group_query = "SELECT CSGRPID FROM CONSENT_GROUP WHERE SID =" +SID;
            ResultSet group_rs = stmt.executeQuery(consent_group_query);
            while(group_rs.next()){
                    Statement stmt1 = conn.createStatement();
                    String search_consent_query = "select CONSENTID, CONTACT_COPTION from CONSENT where SID=" + SID +"  and CSGRPID = "+group_rs.getInt(1)+" and ISPUBLISH=1 order by CPUBLISHDTC DESC LIMIT 1";
                    ResultSet consent_rs = stmt1.executeQuery(search_consent_query);
                    String query_said_insert="";
                    while(consent_rs.next()){              
                        Statement stmt2 = conn.createStatement();                    
                        if(consent_rs.getInt(2)==1)  query_said_insert = "insert into consent_subject(SAID, CONSENTID,SITEID,CS_CONTACT_STAGE) values("+SAID+", "+consent_rs.getInt(1)+", "+SITEID+",1);";
                        else   query_said_insert = "insert into consent_subject(SAID, CONSENTID,SITEID,CS_UNCONTACT_STAGE) values("+SAID+", "+consent_rs.getInt(1)+", "+SITEID+",1);";
                        stmt2.executeUpdate(query_said_insert);
                        int insertedCSID = getLastInsertID(stmt2);
                        
                        // CONSENT_SUBJECT_LOG - CREATE
                        String consentSubjectLogPrevQuery = selectPreviousInformation(stmt, "CONSENT_SUBJECT_LOG", "CONSENT_SUBJECT", tableSchemaName);
                        String consentSubjectLogInsertquery = consentSubjectLogPrevQuery+",'SITE', "+INVID+",'CREATE',NOW() from CONSENT_SUBJECT where CSID="+insertedCSID;
                        stmt2.executeUpdate(consentSubjectLogInsertquery);
                        
                        stmt2.close();
                    }
                    stmt1.close();
            }
        

            stmt.close();
            conn.close();
            out.println("success");
        }
 

         else if(type.equals("LOAD_APPL_APPOINTMENTS")){
            JSONArray applicants = new JSONArray();

            //Load Study information
            String SID = request.getParameter("SID");      

            String query1 = "select a.applid from study_applicant sa, applicant a  where sa.SID = "+SID+" and sa.APPLID=a.APPLID group by sa.applid order by sa.SAID;";
            ResultSet rs1 = stmt.executeQuery(query1);

            while(rs1.next()){
                String query2 = "select sa.SAID,sa.APPLID, sa.APPLDTC, sa.SASTAGE, a.APPLNAME, a.APPLMAIL,a.APPLPHONENUM,a.APPLBRTHDTC, a.APPLSEX, a.PASS , sa.SAACTIVE, DATE_FORMAT(sa.SACLOSEDTC ,'%Y-%m-%d %H:%i')  as  SACLOSEDTC  from APPLICANT a, study_applicant sa where sa.APPLID=a.APPLID and sa.APPLID=" +rs1.getInt(1)+" and sa.SID= "+SID+"  ORDER BY sa.SAID desc LIMIT 1;" ;
                
                Statement stmt2 = conn.createStatement();
                ResultSet rs2 = stmt2.executeQuery(query2);
                int SAID=0;
                JSONObject applicant = new JSONObject();     
                while(rs2.next()){   
                     
                    SAID= rs2.getInt("sa.SAID");
                    applicant.put("SAID", SAID);
                     applicant.put("SAACTIVE", rs2.getInt("sa.SAACTIVE") );
                      
                        applicant.put("SACLOSEDTC",  rs2.getString("SACLOSEDTC"));
                    applicant.put("APPLID", rs2.getInt("sa.APPLID"));
                    applicant.put("APPLDTC", rs2.getString("sa.APPLDTC"));
                    applicant.put("SASTAGE", rs2.getInt("sa.SASTAGE"));
                    applicant.put("APPLNAME", rs2.getString("a.APPLNAME"));
                    applicant.put("APPLMAIL", rs2.getString("a.APPLMAIL"));
                    applicant.put("APPLPHONE", rs2.getString("a.APPLPHONENUM"));
                    applicant.put("APPLBIRTH", rs2.getString("a.APPLBRTHDTC"));
                    applicant.put("APPLSEX", rs2.getInt("a.APPLSEX")); 
                    applicant.put("APPLPASS", rs2.getInt("a.PASS")); 
                 
                }
                    
                String exist_query = "select COUNT(APPOINTID)  from APPOINTMENT WHERE SAID ="+ SAID +"  order by APPOINTID DESC LIMIT 1";
                ResultSet exist_rs = stmt2.executeQuery(exist_query);
                int exist=0;
                while(exist_rs.next()){
                    exist=exist_rs.getInt(1);
                }  

                if(exist>0){
                    String reserve_query = "select APPOINTID, DATE_FORMAT(APPOINTDTC,'%Y-%m-%d %H:%i')  as  APPOINTDTC, DATE_FORMAT(IDENTIFYDTC,'%Y-%m-%d %H:%i')  as  IDENTIFYDTC, MEMO, AFID  from APPOINTMENT WHERE SAID ="+ SAID +" order by APPOINTID DESC LIMIT 1";
                    ResultSet reserve_rs = stmt2.executeQuery(reserve_query);
                            
                    while(reserve_rs.next()){
                                applicant.put("VISITDTC", reserve_rs.getString("APPOINTDTC"));
                                applicant.put("CSPASS", reserve_rs.getString("IDENTIFYDTC"));
                                applicant.put("APPOINTID", reserve_rs.getInt("APPOINTID")); 
                                applicant.put("MEMO", reserve_rs.getString("MEMO"));
                                applicant.put("AFID", reserve_rs.getInt("AFID"));                      
                    }            
                }
                stmt2.close();
                applicants.add(applicant);                   
            }

            stmt.close();
            conn.close();
            out.println(applicants);
         }
         
         else if(type.equals("LOAD_APPOINTMENT")){
           // JSONArray applicants = new JSONArray();

            //Load Study information
           String APPOINTID = request.getParameter("APPOINTID");      
            String SAID = request.getParameter("SAID");      

           /*  String query1 = "select applid from study_applicant where SID = "+SID+"   group by applid;"; 
            ResultSet rs1 = stmt.executeQuery(query1);

            while(rs1.next()){
                String query2 = "select sa.SAID,sa.APPLID, sa.APPLDTC, sa.SASTAGE, a.APPLNAME, a.APPLMAIL,a.APPLPHONENUM,a.APPLBRTHDTC, a.APPLSEX, a.PASS from APPLICANT a, study_applicant sa where sa.APPLID=a.APPLID and sa.APPLID=" +rs1.getInt(1)+" and sa.SID= "+SID+"  ORDER BY sa.SAID desc LIMIT 1;" ;
                
                Statement stmt2 = conn.createStatement();
                ResultSet rs2 = stmt2.executeQuery(query2);
                int SAID=0;
                JSONObject applicant = new JSONObject();     
                while(rs2.next()){                    
                    SAID= rs2.getInt("sa.SAID");
                    applicant.put("SAID", SAID);
                    applicant.put("APPLID", rs2.getInt("sa.APPLID"));
                    applicant.put("APPLDTC", rs2.getString("sa.APPLDTC"));
                    applicant.put("SASTAGE", rs2.getInt("sa.SASTAGE"));
                    applicant.put("APPLNAME", rs2.getString("a.APPLNAME"));
                    applicant.put("APPLMAIL", rs2.getString("a.APPLMAIL"));
                    applicant.put("APPLPHONE", rs2.getString("a.APPLPHONENUM"));
                    applicant.put("APPLBIRTH", rs2.getString("a.APPLBRTHDTC"));
                    applicant.put("APPLSEX", rs2.getInt("a.APPLSEX")); 
                    applicant.put("APPLPASS", rs2.getInt("a.PASS")); 
                }
                    
                String exist_query = "select COUNT(APPOINTID)  from APPOINTMENT WHERE APPOINTID ="+APPOINTID;
                ResultSet exist_rs = stmt2.executeQuery(exist_query);
                int exist=0;
                while(exist_rs.next()){
                    exist=exist_rs.getInt(1);
                }  
 
                */
                 String query2 = "select sa.SAID,sa.APPLID, sa.APPLDTC, sa.SASTAGE, a.APPLNAME, a.APPLMAIL,a.APPLPHONENUM,a.APPLBRTHDTC, a.APPLSEX, a.PASS , sa.SAACTIVE ,sa.SACLOSEDTC from APPLICANT a, study_applicant sa where sa.APPLID=a.APPLID and sa.SAID=" +SAID ;
                
                Statement stmt2 = conn.createStatement();
                ResultSet rs2 = stmt.executeQuery(query2);
               // int SAID=0;
                JSONObject applicant = new JSONObject();     
                while(rs2.next()){                    
                    //SAID= rs2.getInt("sa.SAID");
                  //  applicant.put("SAID", SAID);
                    applicant.put("APPLID", rs2.getInt("sa.APPLID"));
                    applicant.put("APPLDTC", rs2.getString("sa.APPLDTC"));
                    applicant.put("SASTAGE", rs2.getInt("sa.SASTAGE"));
                    applicant.put("APPLNAME", rs2.getString("a.APPLNAME"));
                    applicant.put("APPLMAIL", rs2.getString("a.APPLMAIL"));
                    applicant.put("APPLPHONE", rs2.getString("a.APPLPHONENUM"));
                    applicant.put("APPLBIRTH", rs2.getString("a.APPLBRTHDTC"));
                    applicant.put("APPLSEX", rs2.getInt("a.APPLSEX")); 
                    applicant.put("APPLPASS", rs2.getInt("a.PASS")); 
                     applicant.put("SAACTIVE", rs2.getInt("sa.SAACTIVE")); 
                       applicant.put("SAACTIVE", rs2.getInt("sa.SACLOSEDTC")); 
                }
                    

               // JSONObject applicant = new JSONObject();    
                if(APPOINTID.equals("0")){ // new appoint
                         
                }
                else {
                    String reserve_query = "select  APPOINTID, DATE_FORMAT(APPOINTDTC,'%Y-%m-%d %H:%i')  as  APPOINTDTC, DATE_FORMAT(IDENTIFYDTC,'%Y-%m-%d %H:%i')  as  IDENTIFYDTC, MEMO, AFID  from APPOINTMENT WHERE APPOINTID ="+APPOINTID;
                    ResultSet reserve_rs = stmt.executeQuery(reserve_query);
                            
                    while(reserve_rs.next()){
                                applicant.put("VISITDTC", reserve_rs.getString("APPOINTDTC"));
                                applicant.put("IDENTIFYDTC", reserve_rs.getString("IDENTIFYDTC"));
                                applicant.put("APPOINTID", reserve_rs.getInt("APPOINTID")); 
                                applicant.put("MEMO", reserve_rs.getString("MEMO"));
                                applicant.put("AFID", reserve_rs.getInt("AFID"));                      
                    }    
                }

                //stmt2.close();
               // applicants.add(applicant);                   
           // }

            stmt.close();
            conn.close();
            out.println(applicant);
         }
  /*     
 else if(type.equals("LOAD_APPL_APPOINTMENTS")){
            JSONArray applicants = new JSONArray();

            //Load Study information
            String SID = request.getParameter("SID");           
            
            String query = "select  sa.SAID,sa.APPLID, sa.APPLDTC, sa.SASTAGE, a.APPLNAME, a.APPLMAIL,a.APPLPHONENUM,a.APPLBRTHDTC, a.APPLSEX, a.PASS from APPLICANT a, study_applicant sa where sa.APPLID=a.APPLID and sa.SID= "+SID+" and sa.SASTAGE not in (9)  ORDER BY sa.SAID desc;" ;
            ResultSet rs = stmt.executeQuery(query);
            int SAID=0;
            while(rs.next()){
                JSONObject applicant = new JSONObject();      
                SAID= rs.getInt("sa.SAID");
                applicant.put("SAID", SAID);
                applicant.put("APPLID", rs.getInt("sa.APPLID"));
                applicant.put("APPLDTC", rs.getString("sa.APPLDTC"));
                applicant.put("SASTAGE", rs.getInt("sa.SASTAGE"));
                applicant.put("APPLNAME", rs.getString("a.APPLNAME"));
                applicant.put("APPLMAIL", rs.getString("a.APPLMAIL"));
                applicant.put("APPLPHONE", rs.getString("a.APPLPHONENUM"));
                applicant.put("APPLBIRTH", rs.getString("a.APPLBRTHDTC"));
                applicant.put("APPLSEX", rs.getInt("a.APPLSEX")); 
                applicant.put("APPLPASS", rs.getInt("a.PASS")); 
               
    
                Statement stmt11 = conn.createStatement();
             
                try{              
                    String exist_query = "select COUNT(APPOINTID)  from APPOINTMENT WHERE SAID ="+ SAID +"  order by APPOINTID DESC LIMIT 1";
                    ResultSet exist_rs = stmt11.executeQuery(exist_query);
                        int exist=0;
                    while(exist_rs.next()){
                           exist=exist_rs.getInt(1);
                            
                                           
                    }  
                    if(exist>0){

                    String reserve_query = "select APPOINTID, DATE_FORMAT(APPOINTDTC,'%Y-%m-%d %H:%i')  as  APPOINTDTC, DATE_FORMAT(IDENTIFYDTC,'%Y-%m-%d %H:%i')  as  IDENTIFYDTC, MEMO, AFID  from APPOINTMENT WHERE SAID ="+ SAID +" order by APPOINTID DESC LIMIT 1";
                    ResultSet reserve_rs = stmt11.executeQuery(reserve_query);
                        
                    while(reserve_rs.next()){
                            applicant.put("VISITDTC", reserve_rs.getString("APPOINTDTC"));
                            applicant.put("CSPASS", reserve_rs.getString("IDENTIFYDTC"));
                            applicant.put("APPOINTID", reserve_rs.getInt("APPOINTID")); 
                             applicant.put("MEMO", reserve_rs.getString("MEMO"));
                            applicant.put("AFID", reserve_rs.getInt("AFID"));                      
                    }            
                    }
                    stmt11.close();
                    applicants.add(applicant);
                }catch(Exception e1){
                    stmt11.close();
                }
            }

            stmt.close();
            conn.close();
            out.println(applicants);
         }
         */

         /*
           해당 연구의 하나의 동의서에 대해서 현재 설명요청한 모든 대상자 조회
        */
        else if(type.equals("GET_REQUEST_LIST")){         
            String SID =request.getParameter("SID");    
            String CONSENTID = request.getParameter("CONSENTID");           
  
            JSONArray applicants = new JSONArray();
      
            String cs_sa_query = "select  cs.csid, sa.applid, cs.said,  DATE_FORMAT(cs.csrequestdtc ,'%Y-%m-%d %H:%i')  as requestdtc from study_applicant sa , consent_subject cs where cs.SAID=sa.SAID and cs.CS_CONTACT_STAGE=4 and cs.CSSTARTDTC is null and cs.CONSENTID="+CONSENTID;
            ResultSet cs_sa_rs = stmt.executeQuery(cs_sa_query);
            
            while(cs_sa_rs.next()){
                JSONObject applicant = new JSONObject();    
                applicant.put("SAID", cs_sa_rs.getInt("cs.said"));
                applicant.put("CSID", cs_sa_rs.getInt("cs.csid"));
                applicant.put("REQUESTDTC", cs_sa_rs.getString("requestdtc"));
                 
                Statement stmt11 = conn.createStatement();
             
                try{           
                    String appl_query = "select APPLNAME from APPLICANT  WHERE  applid ="+ cs_sa_rs.getInt("sa.applid");
                    ResultSet appl_rs = stmt11.executeQuery(appl_query);
                        
                    while(appl_rs.next()){
                            applicant.put("APPLNAME", appl_rs.getString("APPLNAME"));       
                    }            
                    
                    stmt11.close();
                    applicants.add(applicant);
                }catch(Exception e1){
                    stmt11.close();
                }
                            
            }          
            stmt.close();
            conn.close();
            out.println(applicants);
        }
        

         /*
           해당 연구의 하나의 동의서에 대해서 현재 설명요청한 모든 대상자 조회
        */
        else if(type.equals("GET_START_LIST")){         
            String SID =request.getParameter("SID");    
            String CONSENTID = request.getParameter("CONSENTID");           
  
            JSONArray applicants = new JSONArray();
      
            String cs_sa_query = "select  cs.csid, sa.applid, cs.said,  DATE_FORMAT(cs.csstartdtc ,'%Y-%m-%d %H:%i')  as csstartdtc from study_applicant sa , consent_subject cs where cs.SAID=sa.SAID and cs.CS_CONTACT_STAGE=5 and cs.CSENDDTC is null and cs.CONSENTID="+CONSENTID;
            ResultSet cs_sa_rs = stmt.executeQuery(cs_sa_query);
            
            while(cs_sa_rs.next()){
                JSONObject applicant = new JSONObject();    
                applicant.put("SAID", cs_sa_rs.getInt("cs.said"));
                applicant.put("CSID", cs_sa_rs.getInt("cs.csid"));
                applicant.put("CSSTARTDTC", cs_sa_rs.getString("csstartdtc"));
                 
                Statement stmt11 = conn.createStatement();
             
                try{           
                    String appl_query = "select APPLNAME from APPLICANT  WHERE  applid ="+ cs_sa_rs.getInt("sa.applid");
                    ResultSet appl_rs = stmt11.executeQuery(appl_query);
                        
                    while(appl_rs.next()){
                            applicant.put("APPLNAME", appl_rs.getString("APPLNAME"));       
                    }            
                    
                    stmt11.close();
                    applicants.add(applicant);
                }catch(Exception e1){
                    stmt11.close();
                }
                            
            }          
            stmt.close();
            conn.close();
            out.println(applicants);
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
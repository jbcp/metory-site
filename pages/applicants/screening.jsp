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
<%@page import="java.text.DateFormat"%>
<%@page import="java.text.SimpleDateFormat"%>

<%
 
    JSONParser db_parser = new JSONParser();
    Object obj = db_parser.parse(new FileReader("../config/dbconfig.json"));
    JSONObject jo = (JSONObject) obj;
    String jdbcDriverValue = (String)jo.get("host");
    String dbId = (String)jo.get("username");
    String dbPass = (String)jo.get("password");
    Class.forName("com.mysql.jdbc.Driver");
    String jdbcDriver = jdbcDriverValue;


    Object object_ips = db_parser.parse(new FileReader("../config/ips.json"));
    JSONObject jobject_ips = (JSONObject) object_ips;       
    
    String dAppIp = (String)jobject_ips.get("dApp");
    String siteIp = (String)jobject_ips.get("site");
    String subjectIp = (String)jobject_ips.get("subject");
    Connection conn= DriverManager.getConnection(jdbcDriver,dbId, dbPass); 
    Statement stmt =null;
    stmt = conn.createStatement();

    int SITEID = (int)session.getAttribute("SITEID");
    int INVID = (int)session.getAttribute("INVID");
    String INVNAME = session.getAttribute("INVNAME").toString();
    String SITENAME = session.getAttribute("SITENAME").toString();

    try{
        //Load Action Type
        String type = request.getParameter("action");

        if(type.equals("load_appl_info")){
             
            JSONArray applicants = new JSONArray();

            //Load Study information
            String SAID = request.getParameter("SAID");

            //get applicant info
            String query = "select a.APPLID,  a.APPLNAME, a.APPLMAIL, a.APPLPHONENUM, a.APPLBRTHDTC, a.APPLSEX,  sa.APPLDTC, sa.SASTAGE, sa.SID from study_applicant sa , APPLICANT a where a.APPLID = sa.APPLID  and sa.SAID= "+SAID;
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
                applicant.put("SASTAGE", rs.getInt(8));
                applicant.put("SID", rs.getInt(9));
                applicants.add(applicant);
            }

            stmt.close();
            conn.close();
            out.println(applicants);

        }
     
        //load_survey_head     
        //  screening_head 테이블  에서 screening_id를 가지고 설문지의 head 에 들어가는 정보를 조회한다.
        else if(type.equals("load_survey_head")){     
            String SCREENING_ID = request.getParameter("SCREENING_ID");      
            JSONArray jarr= new JSONArray();
            
            String query = "select screening_head_id, screening_head_title, screening_head_value from screening_head where screening_id="+SCREENING_ID;   
            ResultSet query_rs = stmt.executeQuery(query);           
                        
            while(query_rs.next()){
                    JSONObject jobj= new JSONObject();
                    jobj.put("SH_ID", query_rs.getInt("screening_head_id")) ;
                    jobj.put("SH_TITLE", query_rs.getString("screening_head_title")) ;
                    jobj.put("SH_VALUE", query_rs.getString("screening_head_value")) ;            
                        
                
                    jarr.add(jobj);
            } 
            out.println(jarr);       
        }

        else if(type.equals("load_question_and_response")){
             
            JSONArray list= new JSONArray();        

            //Load Study information
            String SAID = request.getParameter("SAID");
            String SCREENING_ID = request.getParameter("SCREENING_ID");
   
            //get 문제
            String question_query = "select sq.screening_question_id , q.question_id, q.question_group_id, q.question_content, q.answer_item_group_id, q.answer_type_concept_id,sq.question_seq,ss.survey_section_id, sq.section_seq , ss.survey_section_name, ss.survey_section_info from SCREENING_QUESTION sq, QUESTION q , survey_section ss where sq.screening_id ="+SCREENING_ID+"  and  sq.question_id=q.question_id and sq.survey_section_id =ss.survey_section_id  order by sq.section_seq asc, sq.question_seq asc;";
            ResultSet question_query_rs = stmt.executeQuery(question_query);

            while(question_query_rs.next()){
                Statement stmt2 = conn.createStatement();    
                JSONObject question= new JSONObject();              
                question.put("SCREENING_QUESTION_ID", question_query_rs.getInt("sq.screening_question_id")) ;
                question.put("SECTION_NAME", question_query_rs.getString("ss.survey_section_name")) ;
                question.put("SECTION_INFO", question_query_rs.getString("ss.survey_section_info")) ;
                question.put("SECTION_SEQ", question_query_rs.getString("sq.section_seq")) ;                
                question.put("QUESTION_SEQ", question_query_rs.getInt("sq.question_seq")) ; 
                question.put("QUESTION_CONTENT", question_query_rs.getString("q.question_content")) ;
                question.put("QUESTION_ID", question_query_rs.getInt("q.question_id")) ;
                question.put("ANSWER_ITEM_GROUP_ID", question_query_rs.getInt("q.answer_item_group_id")) ;
                question.put("ANSWER_TYPE_CONCEPT_ID", question_query_rs.getInt("q.answer_type_concept_id")) ;
                question.put("QUESTION_GROUP_ID", question_query_rs.getInt("q.question_group_id")) ;
                
                //응답
                String answer_query = "select SCREENING_ANSWER_ID, ANSWER_SOURCE_VALUE, DATE_FORMAT(ANSWERDTC,'%Y-%m-%d %H:%i') as ANSWERDTC from screening_answer where SCREENING_ID="+SCREENING_ID+" and SAID="+SAID+" and SCREENING_QUESTION_ID="+question_query_rs.getInt("sq.screening_question_id");
                ResultSet answer_query_rs = stmt2.executeQuery(answer_query);
                while(answer_query_rs.next()){
                     question.put("SCREENING_ANSWER_ID", answer_query_rs.getInt("SCREENING_ANSWER_ID")) ;
                     question.put("ANSWER", answer_query_rs.getString("ANSWER_SOURCE_VALUE")) ;
                     question.put("ANSWERDTC", answer_query_rs.getString("ANSWERDTC")) ;
                }

                stmt2.close();  
                list.add(question);

            }

            stmt.close();
            conn.close();
            out.println(list);
        }
        //load_group_questionare_and_answer    
        //load_questionare에서 가져온 문제 중에서 그룹으로 설정되어 있는 반복되는 문제 set과 그 응답을 조회한다.
        //문제 set 은 각각 QUESTION_GROUP_ID로 식별되며, sub_question table에서 문제 문항과 응답 유형을 가져온다. 
        else if(type.equals("load_group_questionare_and_answer")){
            JSONArray list= new JSONArray();        

            //Load Study information
            String SAID = request.getParameter("SAID");
            String SCREENING_ID = request.getParameter("SCREENING_ID"); 
            String QUESTION_GROUP_ID = request.getParameter("QUESTION_GROUP_ID");
                
             //output 
            JSONArray question_list= new JSONArray();        

            //  sub_question table에서 문제 문항과 응답 유형을 가져온다.      
       
               
        //응답
            String answer_query = "select GROUP_ANSWER_ID,SUB_QUESTION_ID, ANSWER_SOURCE_VALUE, DATE_FORMAT(ANSWERDTC,'%Y-%m-%d %H:%i') as ANSWERDTC from group_answer where QUESTION_GROUP_ID="+QUESTION_GROUP_ID+" and SAID="+SAID;
            ResultSet answer_query_rs = stmt.executeQuery(answer_query);
        
            while(answer_query_rs.next()){
                Statement stmt2 = conn.createStatement();    
                JSONObject question= new JSONObject();              
                question.put("GROUP_ANSWER_ID", answer_query_rs.getInt("GROUP_ANSWER_ID")) ;
                question.put("ANSWER", answer_query_rs.getString("ANSWER_SOURCE_VALUE")) ;
                question.put("ANSWERDTC", answer_query_rs.getString("ANSWERDTC")) ;
            
            
                        //        question_list.add(question);
                String question_total_query =  "select count(*) from sub_question  where question_group_id="+QUESTION_GROUP_ID;
        
                ResultSet question_total_query_rs = stmt2.executeQuery(question_total_query);
        
                while(question_total_query_rs.next()){        
                    question.put("TOTAL_SUB_QUESTION_OF_GROUP",question_total_query_rs.getInt(1)) ;                 
                }
                //        question_list.add(question);
                String question_query =  "select subq.sub_question_id, subq.sub_question_content, subq.answer_type_concept_id,subq.sub_question_seq, subq.answer_item_group_id , qg.question_group_name  from sub_question subq, question_group qg  where subq.question_group_id="+QUESTION_GROUP_ID+"  and subq.question_group_id=qg.question_group_id  and subq.sub_question_id="+answer_query_rs.getInt("SUB_QUESTION_ID");
        
                ResultSet question_query_rs = stmt2.executeQuery(question_query);
        
                while(question_query_rs.next()){           
                    question.put("SUB_QUESTION_ID", question_query_rs.getInt("subq.sub_question_id")) ;
                    question.put("QUESTION_CONTENT", question_query_rs.getString("subq.sub_question_content")) ;  

                    question.put("QUESTION_SEQ", question_query_rs.getInt("subq.sub_question_seq")) ; 
                    question.put("ANSWER_ITEM_GROUP_ID", question_query_rs.getInt("subq.answer_item_group_id")) ;
                    question.put("ANSWER_TYPE_CONCEPT_ID", question_query_rs.getInt("subq.answer_type_concept_id")) ;  
                    question.put("QUESTION_GROUP_NAME", question_query_rs.getString("qg.question_group_name")) ; 
                    question.put("QUESTION_GROUP_ID", QUESTION_GROUP_ID) ; 
                    
                }
                
                stmt2.close();  
                list.add(question);

            }
              
            out.println(list);
        }  

        //load_group_questionare    
        //load_questionare에서 가져온 문제 중에서 그룹으로 설정되어 있는 반복되는 문제 set을 조회한다.
        //문제 set 은 각각 QUESTION_GROUP_ID로 식별되며, sub_question table에서 문제 문항과 응답 유형을 가져온다. 
        else if(type.equals("load_group_questionare")){
            String QUESTION_GROUP_ID = request.getParameter("QUESTION_GROUP_ID");
            
            //output 
            JSONArray question_list= new JSONArray();        

            //  sub_question table에서 문제 문항과 응답 유형을 가져온다.      
            String question_query =  "select subq.sub_question_id, subq.sub_question_content, subq.answer_type_concept_id,subq.sub_question_seq, subq.answer_item_group_id , qg.question_group_name  from sub_question subq, question_group qg  where subq.question_group_id="+QUESTION_GROUP_ID+"  and subq.question_group_id=qg.question_group_id order by sub_question_seq asc;";
        
            ResultSet question_query_rs = stmt.executeQuery(question_query);
        
            while(question_query_rs.next()){
                JSONObject question= new JSONObject();              
                    question.put("SUB_QUESTION_ID", question_query_rs.getInt("subq.sub_question_id")) ;
                    question.put("QUESTION_CONTENT", question_query_rs.getString("subq.sub_question_content")) ;                           
                    question.put("QUESTION_SEQ", question_query_rs.getInt("subq.sub_question_seq")) ; 
                    question.put("ANSWER_ITEM_GROUP_ID", question_query_rs.getInt("subq.answer_item_group_id")) ;
                    question.put("ANSWER_TYPE_CONCEPT_ID", question_query_rs.getInt("subq.answer_type_concept_id")) ;  
                    question.put("QUESTION_GROUP_NAME", question_query_rs.getString("qg.question_group_name")) ; 
                    question.put("QUESTION_GROUP_ID", QUESTION_GROUP_ID) ; 
                    question_list.add(question);
            }

            out.println(question_list);
        }  
        //load_answer_group_items     
        //  screening, question 테이블  에서 screening_id를 가지고 설문지의 모든 보기문항에 해당하는 answer_group_no 리스트를 받아.   
        // answer_list table 에서 answer_group_no와 매칭되는 rows를 반환한다.   
        else if(type.equals("load_all_answer_group_items")){     
            String screening_id = request.getParameter("SCREENING_ID");      
            JSONArray jarr= new JSONArray();
            
            String query = "select answer_item_group_id, answer_item_seq , answer_item_id , answer_item_text from answer_item where answer_item_group_id in (select  q.answer_item_group_id from SCREENING_QUESTION sq, QUESTION q where sq.screening_id ="+screening_id+" and  sq.question_id=q.question_id  and answer_item_group_id is not null group by answer_item_group_id order by answer_item_group_id asc);   ";   
            ResultSet query_rs = stmt.executeQuery(query);           
                        
            while(query_rs.next()){
                    JSONObject jobj= new JSONObject();
                    jobj.put("ANSWER_ITEM_GROUP_ID", query_rs.getInt("answer_item_group_id")) ;
                    jobj.put("ANSWER_ITEM_ID", query_rs.getInt("answer_item_id")) ;
                    jobj.put("ANSWER_ITEM_SEQ", query_rs.getInt("answer_item_seq")) ;            
                    
                jobj.put("ANSWER_ITEM_TEXT", query_rs.getString("answer_item_text")) ;              
                jarr.add(jobj);
            } 
             out.println(jarr);       
        }
        //응답 수정 또는 생성
        else if (type.equals("save_response")){
          
            String SAID = request.getParameter("SAID"); 
            String SCREENING_ID = request.getParameter("SCREENING_ID");
            String rows = request.getParameter("RESPONSE");   
                        long nowTimestamp=System.currentTimeMillis();
        SimpleDateFormat sdf = new SimpleDateFormat("YYYY-MM-dd HH:mm:ss");
        Date date = new Date(nowTimestamp);
        String today=sdf.format(date);
          
            //Setting JSON Parser
            JSONParser parser = new JSONParser();
            
            rows = URLDecoder.decode(rows, "UTF-8");
            JSONArray reponses = (JSONArray)parser.parse(rows);
            
             
            for(int i = 0; i < reponses.size(); i++){
                JSONObject aResponse = (JSONObject)reponses.get(i);
                String SCREENING_QUESTION_ID = String.valueOf(aResponse.get("SCREENING_QUESTION_ID"));
                String SCREENING_ANSWER_ID = String.valueOf(aResponse.get("SCREENING_ANSWER_ID"));
                String ANSWER = String.valueOf(aResponse.get("ANSWER"));           
            
                if(SCREENING_ANSWER_ID.equals("0"))  {   //insert
                    String insert_query = "INSERT INTO SCREENING_ANSWER(SCREENING_ID, SAID,SCREENING_QUESTION_ID,  ANSWER_SOURCE_VALUE, ANSWERDTC) values("+SCREENING_ID+", "+SAID+", "+ SCREENING_QUESTION_ID+", '"+ANSWER+"','"+today+ "')";
                    stmt.executeUpdate(insert_query);
                     //Get screening_answer_id
                    int screeening_answer_id=0;
                    String get_last_insert_sponsor = "SELECT LAST_INSERT_ID();";
                    ResultSet rs_sponsor = stmt.executeQuery(get_last_insert_sponsor);
                    while(rs_sponsor.next()){
                        screeening_answer_id = rs_sponsor.getInt(1);
                    }

                    String insert_log_query = "INSERT INTO SCREENING_ANSWER_LOG(SCREENING_ID, SAID,SCREENING_QUESTION_ID,  ANSWER_SOURCE_VALUE, ANSWERDTC, WHO, HOW, WHO_ID, LOGDTC, SCREENING_ANSWER_ID) values("+SCREENING_ID+", "+SAID+", "+ SCREENING_QUESTION_ID+", '"+ANSWER+"','"+today+ "','실시기관','CREATE',"+INVID+", '"+today+"',"+screeening_answer_id+")";
                    stmt.executeUpdate(insert_log_query);
                }              
                else {//update  (SCREENING_ID, SAID,SCREENING_QUESTION_ID,  ANSWER_SOURCE_VALUE, ANSWERDTC) values("

                     String previous_data_query = "select ANSWER_SOURCE_VALUE from SCREENING_ANSWER WHERE SCREENING_ANSWER_ID="+SCREENING_ANSWER_ID;
                   ResultSet rs_sponsor = stmt.executeQuery(previous_data_query);
                   String previous_data="";
                       while(rs_sponsor.next()){
                        previous_data = rs_sponsor.getString(1);
                    }
                    if(!previous_data.equals(ANSWER)){
                      String update_query = "UPDATE SCREENING_ANSWER SET ANSWER_SOURCE_VALUE='"+ANSWER+"'  where  SCREENING_ANSWER_ID= "+ SCREENING_ANSWER_ID + "  and SAID="+SAID;
                      stmt.executeUpdate(update_query);
                      
                    // log
                      String insert_log_query = "INSERT INTO SCREENING_ANSWER_LOG(SCREENING_ID, SAID, SCREENING_QUESTION_ID,  ANSWER_SOURCE_VALUE,  WHO, HOW,WHO_ID, LOGDTC,SCREENING_ANSWER_ID) values("+SCREENING_ID+", "+SAID+", "+ SCREENING_QUESTION_ID+", '"+ANSWER+"','실시기관','UPDATE',"+INVID+", '"+today+"',"+SCREENING_ANSWER_ID+")";
                      stmt.executeUpdate(insert_log_query);   
                        
                      }               
                }
            }
                       JSONObject job=new JSONObject();
                        job.put("subjectIp",subjectIp);
            job.put("result","success");
            job.put("last_updatedtc", nowTimestamp);
            out.println(job);        

        }   //load_answer_group_items     
        //  screening, question 테이블  에서 screening_id를 가지고 설문지의 모든 보기문항에 해당하는 answer_group_no 리스트를 받아.   
        // answer_list table 에서 answer_group_no와 매칭되는 rows를 반환한다.   
        else if(type.equals("load_all_answer_group_items")){     
            String screening_id = request.getParameter("SCREENING_ID");      
            JSONArray jarr= new JSONArray();
        
            String query = "select answer_item_group_id, answer_item_seq , answer_item_id , answer_item_text from answer_item where answer_item_group_id in (select  q.answer_item_group_id from SCREENING_QUESTION sq, QUESTION q where sq.screening_id ="+screening_id+" and  sq.question_id=q.question_id  and answer_item_group_id is not null group by answer_item_group_id order by answer_item_group_id asc);   ";   
            ResultSet query_rs = stmt.executeQuery(query);           
                        
            while(query_rs.next()){
                    JSONObject jobj= new JSONObject();
                    jobj.put("ANSWER_GROUP_NO", query_rs.getInt("answer_item_group_id")) ;
                    jobj.put("ANSWER_LIST_ID", query_rs.getInt("answer_item_id")) ;
                    jobj.put("ANSWER_SEQ", query_rs.getInt("answer_item_seq")) ;            
                        
                    jobj.put("ANSWER_ITEM_NAME", query_rs.getString("answer_item_text")) ;              
                    jarr.add(jobj);
            } 
            out.println(jarr);       
        }
        //screening_answer_id 로 audit trail
        else if (type.equals("getAudit")){         
        
            String SCREENING_ANSWER_ID = request.getParameter("SCREENING_ANSWER_ID");
            JSONArray jarr= new JSONArray();
            
            String query = "select ANSWER_SOURCE_VALUE, DATE_FORMAT(LOGDTC,'%Y-%m-%d %H:%i') as LOGDTC, WHO, WHO_ID, HOW , SCREENING_QUESTION_ID from SCREENING_ANSWER_LOG WHERE SCREENING_ANSWER_ID="+SCREENING_ANSWER_ID+" order by LOGDTC asc;";   
            ResultSet query_rs = stmt.executeQuery(query);           
            String who_query=""; 
            // int screening_question_id=0;
            while(query_rs.next()){
                JSONObject jobj= new JSONObject();
                Statement stmt2 = conn.createStatement();    
                jobj.put("ANSWER_SOURCE_VALUE", query_rs.getString("ANSWER_SOURCE_VALUE")) ;
                jobj.put("LOGDTC", query_rs.getString("LOGDTC")) ;
                jobj.put("WHO", query_rs.getString("WHO")) ;  
                 jobj.put("WHO_ID", query_rs.getInt("WHO_ID")) ;  
                 jobj.put("HOW", query_rs.getString("HOW")) ;            
                if(query_rs.getString("WHO").equals("대상자"))  {
                     who_query="select APPLNAME, APPLMAIL from applicant where applid="+query_rs.getInt("WHO_ID");
                     

                }
                else if(query_rs.getString("WHO").equals("실시기관"))  {
                      who_query="select INVNAME, INVMAIL from investigator where INVID="+query_rs.getInt("WHO_ID");
                    
                }
              
                ResultSet who_query_rs = stmt2.executeQuery(who_query); 
                while(who_query_rs.next()){
                     jobj.put("WHO_NAME", who_query_rs.getString(1)) ;      
                     jobj.put("WHO_MAIL", who_query_rs.getString(2)) ;    
                }
                //String question_query="select "
                // ResultSet who_query_rs = stmt2.executeQuery(who_query); 
              // while(who_query_rs.next()){
               //      jobj.put("WHO_NAME", who_query_rs.getString(1)) ;        
               // }
               

                jarr.add(jobj);
                 stmt2.close();
            } 
            out.println(jarr); 
        } 
        //screening_answer_id 로 subgroup의 하나의 문제 audit trail
        else if (type.equals("getGroupAudit")){         
        
            String GROUP_ANSWER_ID = request.getParameter("GROUP_ANSWER_ID");
            JSONArray jarr= new JSONArray();
            
            String query = "select ANSWER_SOURCE_VALUE, DATE_FORMAT(LOGDTC,'%Y-%m-%d %H:%i') as LOGDTC, WHO, WHO_ID, HOW from GROUP_ANSWER_LOG WHERE GROUP_ANSWER_ID="+GROUP_ANSWER_ID+" order by LOGDTC asc ;";   
            ResultSet query_rs = stmt.executeQuery(query);           
            String who_query=""; 
            while(query_rs.next()){
                JSONObject jobj= new JSONObject();
                Statement stmt2 = conn.createStatement();    
                jobj.put("ANSWER_SOURCE_VALUE", query_rs.getString("ANSWER_SOURCE_VALUE")) ;
                jobj.put("LOGDTC", query_rs.getString("LOGDTC")) ;
                jobj.put("WHO", query_rs.getString("WHO")) ;  
                 jobj.put("WHO_ID", query_rs.getInt("WHO_ID")) ;  
                 jobj.put("HOW", query_rs.getString("HOW")) ;            
                if(query_rs.getString("WHO").equals("대상자"))  {
                     who_query="select APPLNAME, APPLMAIL from applicant where applid="+query_rs.getInt("WHO_ID");
                     

                }
                else if(query_rs.getString("WHO").equals("실시기관"))  {
                      who_query="select INVNAME, INVMAIL from investigator where INVID="+query_rs.getInt("WHO_ID");
                    
                }
                ResultSet who_query_rs = stmt2.executeQuery(who_query); 
                while(who_query_rs.next()){
                     jobj.put("WHO_NAME", who_query_rs.getString(1)) ;    
                      jobj.put("WHO_MAIL", who_query_rs.getString(2)) ;        
                }
                jarr.add(jobj);
                 stmt2.close();
            } 
            out.println(jarr);  
        } 
        //said 와 screening id, question_group_id 로 subgroup의 전체의 audit trail
        else if (type.equals("get_subgroup_audit")){         
            String SAID = request.getParameter("SAID");
            String SCREENING_ID = request.getParameter("SCREENING_ID");
            String QUESTION_GROUP_ID = request.getParameter("QUESTION_GROUP_ID");
           
            JSONArray jarr= new JSONArray();
            
            String query = "select l.HOW, sq.SUB_QUESTION_CONTENT, l.ANSWER_SOURCE_VALUE, l.WHO, l.WHO_ID,DATE_FORMAT(l.LOGDTC,'%Y-%m-%d %H:%i') as LOGDTC, l.WHO, l.WHO_ID  from GROUP_ANSWER_LOG l, sub_question sq WHERE l.SAID="+SAID+" and l.SCREENING_ID="+SCREENING_ID+"  and l.QUESTION_GROUP_ID="+QUESTION_GROUP_ID+" and sq.SUB_QUESTION_ID = l.SUB_QUESTION_ID order by LOGDTC asc "; 


            ResultSet query_rs = stmt.executeQuery(query);           
            String who_query=""; 
            while(query_rs.next()){
                JSONObject jobj= new JSONObject();
                Statement stmt2 = conn.createStatement();    
                jobj.put("ANSWER_SOURCE_VALUE", query_rs.getString("ANSWER_SOURCE_VALUE")) ;
                jobj.put("LOGDTC", query_rs.getString("LOGDTC")) ;
                jobj.put("WHO", query_rs.getString("WHO")) ;  
                 jobj.put("WHO_ID", query_rs.getInt("WHO_ID")) ;  
                 jobj.put("HOW", query_rs.getString("HOW")) ;  
                  jobj.put("QUESTION", query_rs.getString("SUB_QUESTION_CONTENT")) ;           
                if(query_rs.getString("WHO").equals("대상자"))  {
                     who_query="select APPLNAME, APPLMAIL from applicant where applid="+query_rs.getInt("WHO_ID");
                     

                }
                else if(query_rs.getString("WHO").equals("실시기관"))  {
                      who_query="select INVNAME, INVMAIL from investigator where INVID="+query_rs.getInt("WHO_ID");
                    
                }
                ResultSet who_query_rs = stmt2.executeQuery(who_query); 
                while(who_query_rs.next()){
                     jobj.put("WHO_NAME", who_query_rs.getString(1)) ;    
                      jobj.put("WHO_MAIL", who_query_rs.getString(2)) ;        
                }
                jarr.add(jobj);
                 stmt2.close();
            } 
            out.println(jarr);  
        } 

        //반복되는 문제그룹이 대답 저장
        else if (type.equals("save_group_response")){
          
            String SAID = request.getParameter("SAID"); 
            String SCREENING_ID = request.getParameter("SCREENING_ID");
            String rows = request.getParameter("RESPONSE");   
                
            
            DecimalFormat df = new DecimalFormat("00");
            Calendar calendar = Calendar.getInstance();
            String year = Integer.toString(calendar.get(Calendar.YEAR)); 
            String month = df.format(calendar.get(Calendar.MONTH) + 1); 
            String day = df.format(calendar.get(Calendar.DATE)); 
            String hour = df.format(calendar.get(Calendar.HOUR_OF_DAY));
            String minute = df.format(calendar.get(Calendar.MINUTE));
            String second = df.format(calendar.get(Calendar.SECOND));    
            String today = year+"-"+month+"-"+day+" "+hour+":"+minute+":"+second;

        //Setting JSON Parser
            JSONParser parser = new JSONParser();
                
            rows = URLDecoder.decode(rows, "UTF-8");
            JSONArray reponses = (JSONArray)parser.parse(rows);
                
                //Insert reponses
            for(int i = 0; i < reponses.size(); i++){
                JSONObject aResponse = (JSONObject)reponses.get(i);
                String QUESTION_GROUP_ID = String.valueOf(aResponse.get("QUESTION_GROUP_ID"));
                String SUB_QUESTION_ID = String.valueOf(aResponse.get("SUB_QUESTION_ID"));
                String ANSWER = String.valueOf(aResponse.get("ANSWER"));           
                String GROUP_ANSWER_ID = String.valueOf(aResponse.get("GROUP_ANSWER_ID"));
                String CRUD = String.valueOf(aResponse.get("CRUD"));

                if(CRUD.equals("c"))  {//insert
                    String insert_query = "INSERT INTO GROUP_ANSWER(QUESTION_GROUP_ID, SUB_QUESTION_ID, ANSWER_SOURCE_VALUE, ANSWERDTC, SAID, SCREENING_ID) values("+QUESTION_GROUP_ID+", "+SUB_QUESTION_ID+", '"+ ANSWER+"','"+today+"',"+SAID+","+SCREENING_ID +")";
                    stmt.executeUpdate(insert_query);
                            //Get group_answer_id
                    int group_answer_id=0;
                    String get_last = "SELECT LAST_INSERT_ID();";
                    ResultSet rs_last_inserted = stmt.executeQuery(get_last);
                    while(rs_last_inserted.next()){
                        group_answer_id = rs_last_inserted.getInt(1);
                    }

                    // log
                    String insert_log_query = "INSERT INTO GROUP_ANSWER_LOG(QUESTION_GROUP_ID, SUB_QUESTION_ID, ANSWER_SOURCE_VALUE, ANSWERDTC, SAID, SCREENING_ID, WHO,HOW,WHO_ID, LOGDTC, GROUP_ANSWER_ID) values("+QUESTION_GROUP_ID+", "+SUB_QUESTION_ID+", '"+ ANSWER+"','"+today+"',"+SAID+","+SCREENING_ID+",'실시기관','CREATE',"+INVID+",'"+today+"',"+group_answer_id+") ";
                    stmt.executeUpdate(insert_log_query);

                } 
                else if(CRUD.equals("d")){
                    String delete_query = "DELETE FROM GROUP_ANSWER  WHERE GROUP_ANSWER_ID="+GROUP_ANSWER_ID;
                    stmt.executeUpdate(delete_query);                    
                    // log
                    String insert_log_query = "INSERT INTO GROUP_ANSWER_LOG(QUESTION_GROUP_ID, SUB_QUESTION_ID, ANSWER_SOURCE_VALUE, ANSWERDTC, SAID, SCREENING_ID, WHO,HOW,WHO_ID, LOGDTC, GROUP_ANSWER_ID) values("+QUESTION_GROUP_ID+", "+SUB_QUESTION_ID+", '"+ ANSWER+"','"+today+"',"+SAID+","+SCREENING_ID+",'실시기관','DELETE',"+INVID+",'"+today+"',"+GROUP_ANSWER_ID+") ";
                    stmt.executeUpdate(insert_log_query);
                }                
                else if(CRUD.equals("r")) {

                    String previous_data_query = "select ANSWER_SOURCE_VALUE from GROUP_ANSWER WHERE GROUP_ANSWER_ID="+GROUP_ANSWER_ID;
                    ResultSet rs_sponsor = stmt.executeQuery(previous_data_query);
                    String previous_data="";
                    while(rs_sponsor.next()){
                        previous_data = rs_sponsor.getString(1);
                    }
                    if(!previous_data.equals(ANSWER)){
                         String update_query = "UPDATE GROUP_ANSWER SET ANSWER_SOURCE_VALUE='"+ANSWER+"'  where  GROUP_ANSWER_ID= "+ GROUP_ANSWER_ID + "  and SAID="+SAID;
                         stmt.executeUpdate(update_query);
                         // log
                          String insert_log_query = "INSERT INTO GROUP_ANSWER_LOG(QUESTION_GROUP_ID, SUB_QUESTION_ID, ANSWER_SOURCE_VALUE, SAID, SCREENING_ID,WHO,HOW,WHO_ID, LOGDTC,GROUP_ANSWER_ID) values("+QUESTION_GROUP_ID+", "+SUB_QUESTION_ID+", '"+ ANSWER+"',"+SAID+","+SCREENING_ID+",'실시기관','UPDATE',"+INVID+",'"+today+"',"+GROUP_ANSWER_ID+")";
                         stmt.executeUpdate(insert_log_query);   
                    }    
                }
             
                
            }
             out.println("success");
        }

    //////////////////////
         conn.close();
         stmt.close();
    }catch(Exception e){
        e.printStackTrace();
        out.println(e.toString());
    }
    finally{
         if(stmt!=null) { try{stmt.close();} catch(Exception e){}}  stmt.close();
         if(conn!=null) { try{conn.close();} catch(Exception e){}}  conn.close();
         
          
    }
%>
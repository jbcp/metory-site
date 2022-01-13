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
    
    
    Object object_ips = db_parser.parse(new FileReader("../config/ips.json"));
    JSONObject jobject_ips = (JSONObject) object_ips;       
    
    String dAppIp = (String)jobject_ips.get("dApp");

 
    Class.forName("com.mysql.jdbc.Driver");
    //String jdbcDriver = "jdbc:mysql://"+DB_info.get("ip")+":"+DB_info.get("port")+"/"+DB_info.get("dbName");
    String jdbcDriver = jdbcDriverValue;
    
    Connection conn= DriverManager.getConnection(jdbcDriver,dbId, dbPass); 
    Statement stmt =null;
    stmt = conn.createStatement();


        int INVID = (int)session.getAttribute("INVID");
     int SITEID = (int)session.getAttribute("SITEID");
     String INVEMAIL = session.getAttribute("INVMAIL").toString();    

try{
    String type = request.getParameter("action");
 
     /*
        목적: 블록체인 관리자가 채널 생성이 요청된 연구 리스트 요청
        구현: select * @ STUDY when BCSTAGE>0
        input: NULL
        output: studies
    */
    if(type.equals("load")){
        //연구자가 채널생성을 요청한 경우, 즉 BCSTAGE!=0 인 site 의 study list
       
        String query = "SELECT SID, SITEID, SPONSORID, PRTNO, TITLE, DATE_FORMAT(SCREATEDTC,'%Y-%m-%d %H:%i' ) as SCREATEDTC, BCPROFILE, BCSTAGE, BCCHANNEL FROM STUDY WHERE SITEID = "+SITEID+" and BCSTAGE!=0 order by SCREATEDTC desc";
        log("[METORY log]"+"\t||\t[SITEID]="+SITEID+"\t||\t[INVID]="+INVID+"\t||\t[type]="+type+"\t||\t[QUERY]="+query.replace("'", "\'"));   
        ResultSet rs = stmt.executeQuery(query);

        JSONArray studies = new JSONArray();

        while(rs.next()){
            JSONObject study = new JSONObject();


            study.put("SID", rs.getInt(1));
            study.put("SITEID", rs.getInt(2));
            study.put("SPONSOR", rs.getInt(3));
            study.put("PRTNO", rs.getString(4));
            study.put("TITLE", rs.getString(5));
            study.put("SCREATEDTC", rs.getString(6));
           study.put("BCPROFILE",rs.getString(7));
           study.put("CONTEXTPATH", request.getContextPath() );
            study.put("BCSTAGE", rs.getInt(8));     
            study.put("BCCHANNEL", rs.getString("BCCHANNEL"))  ;
            studies.add(study);
        }
  
        stmt.close();
        conn.close();
       
        out.println(studies);
    }
    /*
        목적: 블록체인 관리자가 각 연구의 동의서 저장 정보 로드하기위해 필요한 정보 전달
        구현: select PRTNO @ STUDY
        input: SID
        output: PRTNO, DAPPIP, SITECODE, INVBCID
    */
    else if (type.equals("load_consents")){   
        String SID = request.getParameter("SID");    
            String SITENAME = session.getAttribute("SITENAME").toString();
        JSONObject study = new JSONObject();

        String query = "SELECT SPONSORID, PRTNO, BCCHANNEL, BCSTAGE FROM STUDY WHERE SID = "+SID ;
          log("[METORY log]"+"\t||\t[SITEID]="+SITEID+"\t||\t[INVID]="+INVID+"\t||\t[type]="+type+"\t||\t[QUERY]="+query.replace("'", "\'"));   
        ResultSet rs = stmt.executeQuery(query);

        while(rs.next()){
         study.put("PRTNO",rs.getString(2));
          study.put("BCCHANNEL",rs.getString(3));
           study.put("BCSTAGE",rs.getInt(4));
        }

        study.put("DAPPIP", dAppIp);
        study.put("SITECODE",SITENAME);
        study.put("INVBCID", INVEMAIL);

        out.println(study);

    }
    
    else if (type.equals("load_consent_info")){   

        String SID = request.getParameter("SID");  
        String CONSENTID = request.getParameter("CONSENTID");  
         String SAID = request.getParameter("SAID");    
           
         
        JSONObject study = new JSONObject();

        String query = "SELECT TITLE FROM STUDY WHERE SID = "+SID ;
          ResultSet rs = stmt.executeQuery(query);

        while(rs.next()){
         study.put("TITLE",rs.getString(1));  
        }
        String PI_query = "SELECT i.INVNAME FROM STUDY_INV si, investigator i WHERE si.SIROLECODE=1 and  si.INVID=i.INVID and si.SID = "+SID ;
         ResultSet pi_rs = stmt.executeQuery(PI_query);

        while(pi_rs.next()){
         study.put("PI",pi_rs.getString(1));  
        }
       String consent_query = "SELECT c.CSGRPID, c.CVERSION, c.CFILENAME, c.CFILE, c.CFILE_HASH, cg.CSGRPTITLE FROM  CONSENT c, CONSENT_GROUP cg where  cg.CSGRPID=c.CSGRPID and c.CONSENTID = "+CONSENTID ;
         ResultSet consent_rs = stmt.executeQuery(consent_query);

        while(consent_rs.next()){
         study.put("CVERSION",consent_rs.getString("c.CVERSION"));  
          study.put("CFILE_HASH",consent_rs.getString("c.CFILE_HASH"));  
           study.put("CSGRPTITLE",consent_rs.getString("cg.CSGRPTITLE"));  
            study.put("CFILE",consent_rs.getString("c.CFILE"));  
                        study.put("CFILENAME",consent_rs.getString("c.CFILENAME"));  
        }

               String appl_query = "SELECT appl.APPLNAME , appl.APPLID, sa.SAID from STUDY_APPLICANT sa, APPLICANT appl where sa.SAID="+SAID+"  and appl.APPLID=sa.APPLID " ;
         ResultSet appl_rs = stmt.executeQuery(appl_query);

        while(appl_rs.next()){
         study.put("APPLNAME",appl_rs.getString("appl.APPLNAME"));  
        
           // study.put("CVERSION",consent_rs.getString("c.CVERSION"));  
        }

        out.println(study);

    }
    /*
        목적: 블록체인 관리자가 하나의 연구 프로파일을 플랫폼에 저장 후 DAPP 서버에 프로파일을 전송하기 위한 정보 조회
        구현: UPDATE BCSTAGE, BCPROFILE @ STUDY
        input: SID, PFILEPATH
        output: studies(PRTNO, DAPPIP, SITEID, SPONSORID)
    */
    else if(type.equals("saveProfile")){
        //update the filepath of profile.json and blockchain_status on BCPROFILE, BCSTAGE each at STUDY TABLE
        

       
        String SID = request.getParameter("SID");       
        String encodefilepath = request.getParameter("PFILEPATH");  
        String filepath = URLDecoder.decode(encodefilepath, "UTF-8");
        // BCSTAGE=3; 프로파일 설치
        // String publish_query = "UPDATE STUDY SET BCSTAGE = 3, BCPROFILE='"+filepath+"'  WHERE SID = "+SID +" and SITEID="+SITEID;
        String publish_query = "UPDATE STUDY SET BCPROFILE='"+filepath+"'  WHERE SID = "+SID +" and SITEID="+SITEID;
        stmt.executeUpdate(publish_query);

        // STUDY_LOG 저장 - UPDATE
        String studyLogPrevQuery = selectPreviousInformation(stmt, "STUDY_LOG", "STUDY", tableSchemaName);
        String studyLogInsertquery = studyLogPrevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from STUDY where SID="+SID+" and SITEID="+SITEID;
        stmt.executeUpdate(studyLogInsertquery); 

        String query = "SELECT STUDY.SPONSORID, STUDY.PRTNO , SITE.SITENAME   FROM STUDY , SITE  WHERE SITE.SITEID=STUDY.SITEID and STUDY.SID = "+SID +" and SITE.SITEID="+SITEID;
        ResultSet rs = stmt.executeQuery(query);

        JSONArray studies = new JSONArray();

        while(rs.next()){
            JSONObject study = new JSONObject();
            study.put("SPONSORID", rs.getInt(1));
            study.put("PRTNO", rs.getString(2));           
            study.put("DAPPIP", dAppIp);
            study.put("SITEID", SITEID);
            study.put("SITENAME", rs.getString(3));
            studies.add(study);
        }

       
        out.println(studies);
        stmt.close();
        conn.close();
      
    }
    /*
        목적: 블록체인 관리자가 각 연구의 채널 상태 변경
        구현: update BCSTAGE @ STUDY
        input: SID
        output: success
              
        채널 상태 옵션값 = ["", "연구자 요청", "피어정보 전달", "프로파일 설치", "채널오픈", "채널중단", "채널종료"]; //BCSTAGE
    */
    else if(type.equals("CHANGE_BCSTAGE")){
        String BCSTAGE = request.getParameter("STAGE");
        String SID = request.getParameter("SID");           
       
        String modify_study_query = "UPDATE STUDY SET BCSTAGE = "+BCSTAGE+"  WHERE SID = "+SID + " and SITEID="+SITEID;
        stmt.executeUpdate(modify_study_query);

        // STUDY_LOG 저장 - UPDATE
        String studyLogPrevQuery = selectPreviousInformation(stmt, "STUDY_LOG", "STUDY", tableSchemaName);
        String studyLogInsertquery = studyLogPrevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from STUDY where SID="+SID+" and SITEID="+SITEID;
        stmt.executeUpdate(studyLogInsertquery);

        stmt.close();
        conn.close();
        out.println("success");
    }
      /*
        SAVE_CHANNEL
        목적: 블록체인 관리자가 각 연구의 채널 이름 설정
        구현: update BCSTAGE @ STUDY
        input: SID, BCCHANNEL
        output: success
              
        채널 상태 옵션값 = ["", "연구자 요청", "피어정보 전달", "프로파일 설치", "채널오픈", "채널중단", "채널종료"]; //BCSTAGE
    */
     else if(type.equals("SAVE_CHANNEL")){
        String BCCHANNEL = request.getParameter("BCCHANNEL");
        String SID = request.getParameter("SID");           
       
        String modify_study_query = "UPDATE STUDY SET BCCHANNEL = '"+BCCHANNEL+"'  WHERE SID = "+SID + " and SITEID="+SITEID;
        stmt.executeUpdate(modify_study_query);

        // STUDY_LOG 저장 - UPDATE
        String studyLogPrevQuery = selectPreviousInformation(stmt, "STUDY_LOG", "STUDY", tableSchemaName);
        String studyLogInsertquery = studyLogPrevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from STUDY where SID="+SID+" and SITEID="+SITEID;
        stmt.executeUpdate(studyLogInsertquery);

        stmt.close();
        conn.close();
        out.println("success");
    }
  
  else if (type.equals("load_consent_detail")){   
        String SID = request.getParameter("SID");  
        String CONSENTID = request.getParameter("CONSENTID");         
      
        JSONArray studies = new JSONArray();

        String query = "SELECT  cd.CDTITLE, cd.CDCONTENT, c.CVERSION  FROM CONSENT_DETAIL cd , CONSENT c WHERE c.SID = "+SID+" and cd.CONSENTID=c.CONSENTID and c.CONSENTID="+CONSENTID+" ORDER BY cd.CDID asc";
         //     log("[METORY log]"+"\t||\t[SITEID]="+SITEID+"\t||\t[INVID]="+INVID+"\t||\t[type]="+type+"\t||\t[QUERY]="+query.replace("'", "\'"));   
        ResultSet rs = stmt.executeQuery(query);
      
        while(rs.next()){
            JSONObject study_detail = new JSONObject();
           // study.put("size",rs.getInt("count"));
            study_detail.put("CDTITLE",rs.getString("cd.CDTITLE"));
            study_detail.put("CDCONTENT",rs.getString("cd.CDCONTENT"));
     // cversion=rs.getString("c.CVERSION");
            studies.add(study_detail);
        }

       // studies.add(study);

        stmt.close();
        conn.close();
        out.println(studies);

    }
    
 /* else if (type.equals("load_consent_detail")){   
        String SID = request.getParameter("SID");  
         String CONSENTID = request.getParameter("CONSENTID");   
       
      
        JSONArray studies = new JSONArray();

        

        String query = "SELECT  cd.CDTITLE, cd.CDCONTENT, c.CVERSION  FROM CONSENT_DETAIL cd , CONSENT c WHERE c.SID = "+SID+" and cd.CONSENTID=c.CONSENTID and c.CONSENTID="+CONSENTID+" ORDER BY cd.CDID asc";
         log("[METORY log]"+"\t||\t[SITEID]="+SITEID+"\t||\t[INVID]="+INVID+"\t||\t[type]="+type+"\t||\t[QUERY]="+query.replace("'", "\'"));   
        ResultSet rs = stmt.executeQuery(query);
        String cversion="";
        while(rs.next()){
            JSONObject study_detail = new JSONObject();
           // study.put("size",rs.getInt("count"));
            study_detail.put("CDTITLE",rs.getString("cd.CDTITLE"));
            study_detail.put("CDCONTENT",rs.getString("cd.CDCONTENT"));
            cversion=rs.getString("c.CVERSION");
            studies.add(study_detail);
        }

       String study_query = "SELECT SITEID, SPONSORID, PRTNO, TITLE, BCCHANNEL FROM STUDY WHERE SID = "+SID;
        log("[METORY log]"+"\t||\t[SITEID]="+SITEID+"\t||\t[INVID]="+INVID+"\t||\t[type]="+type+"\t||\t[QUERY]="+study_query.replace("'", "\'"));   
        ResultSet study_rs = stmt.executeQuery(study_query);
        JSONObject study = new JSONObject();
        int sponsorid=0;
        int siteid=0;
        while(study_rs.next()){
            sponsorid=study_rs.getInt("SPONSORID");
            siteid=study_rs.getInt("SITEID");
            study.put("PRTNO",study_rs.getString("PRTNO"));
            study.put("TITLE",study_rs.getString("TITLE"));
            study.put("BCCHANNEL",study_rs.getString("BCCHANNEL"));
              
        }

        
        String find_query = "SELECT SPONSORNAME FROM SPONSOR  WHERE SPONSORID = "+sponsorid;
        ResultSet find_rs = stmt.executeQuery(find_query);
  
        while(find_rs.next()){
            
            study.put("SPONSOR_NAME",find_rs.getString("SPONSORNAME"));    
        }

        find_query = "select i.INVNAME, s.SITENAME from investigator i ,site s, study_inv si where i.INVID=si.INVID and s.SITEID=i.SITEID and si.SIROLECODE=1 and si.SID="+SID;
         log("[METORY log]"+"\t||\t[SITEID]="+SITEID+"\t||\t[INVID]="+INVID+"\t||\t[type]="+type+"\t||\t[QUERY]="+find_query.replace("'", "\'"));   
        find_rs = stmt.executeQuery(find_query);
  
        while(find_rs.next()){
            
            study.put("PI_NAME",find_rs.getString("i.INVNAME")); 
             study.put("SITE_NAME",find_rs.getString("s.SITENAME"));    
        }

        study.put("CVERSION",cversion);
        study.put("DAPPIP", dAppIp);
       // study.put("SITECODE",SITENAME);
        //study.put("INVBCID", INVEMAIL);
        studies.add(study);

        stmt.close();
        conn.close();
        out.println(studies);

    }*/
}catch(Exception  e){
 out.println(e.toString());

}finally{
    if(stmt!=null){
     stmt.close();    
    }
    if(conn!=null){   
     conn.close();
    }
}
%>

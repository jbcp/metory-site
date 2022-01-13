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
    Class.forName("com.mysql.jdbc.Driver");
    String jdbcDriver = jdbcDriverValue;
    String tableSchemaName = jdbcDriverValue.split("/")[jdbcDriverValue.split("/").length-1].split("\\?")[0];

    Connection conn= DriverManager.getConnection(jdbcDriver,dbId, dbPass); 
    Statement stmt =null;
    stmt = conn.createStatement();

    //Load User information
    int INVID = (int)session.getAttribute("INVID");
    int SITEID = (int)session.getAttribute("SITEID");


    try{

        //Load Action Type
        String type = request.getParameter("action");
        
        /*
            Create Study
            Input : PRTNO, SPONSOR, STITLE, SAPPLICANT, SSEX, SNUM, INVID, SITEID
            Output : SID
        */
        if(type.equals("create")){       
            //Load Study information
            String PRTNO = request.getParameter("PRTNO");
            String SPONSORID =  request.getParameter("SPONSORID");
            String PIID =  request.getParameter("PIID");
            String STITLE = request.getParameter("STITLE");
            String SAPPLICANT = request.getParameter("SAPPLICANT");
            // if(SAPPLICANT.equals("undefined")) SAPPLICANT=null;
            String SSEX = request.getParameter("SSEX");
            //   if(SSEX.equals("undefined"))SSEX=null;
            String SNUM = request.getParameter("SNUM");
            if(SNUM.equals("")) SNUM = "0";
            String STARGET = request.getParameter("STARGET");
           
            //Protocol No should be unique at a site
            //Check if ProtocolNo exists
            // String check_prtno_exist = "SELECT EXISTS (SELECT * FROM STUDY WHERE PRTNO = '" + PRTNO +"' and SITEID= "+SITEID+" ) AS SUCCESS;";
            String check_prtno_exist = "SELECT count(SID)  FROM study WHERE LOWER(PRTNO) LIKE  '%"+PRTNO+"%' and SITEID="+SITEID;

            ResultSet prtno_exist_rs = stmt.executeQuery(check_prtno_exist);
            int prtno_exist = 0;
            while(prtno_exist_rs.next()){
                prtno_exist = prtno_exist_rs.getInt(1);
            }
        
            if (prtno_exist>=1){ //return error message
                
                out.println("error 4044 : 동일한 프로토콜이 존재하여 연구생성 할 수 없습니다.");
                stmt.close();
                conn.close();
                return;
            }
            //Sponsor
            /*Check if Sponsor exists-사용자 입력으로 의뢰인 추가시 SPONSORID 가 숫자가 아닌 값이 들어오므로 더이상 필요없음.
            String check_sponsor_exist = "SELECT EXISTS (SELECT * FROM SPONSOR WHERE SPONSORID = '" + SPONSORID +"') AS SUCCESS;";
            ResultSet exist_rs = stmt.executeQuery(check_sponsor_exist);
            int exist = 0;
            while(exist_rs.next()){
                exist = exist_rs.getInt(1);
            }

            //error if Sponsor does not exist
            if (exist==0){
                out.println("error 4045: 목록에 없는 의뢰자입니다. 관리자에게 요청하여 주십시오.");                
                stmt.close();
                conn.close();
                return;
            }*/
            /*check if sponsorid is number or string
             string 인 경우 sponsor table에 새로 추가하고 그 아이디값을 받는다.
            */

            if(!SPONSORID.matches("[0-9]+")){ //string 이 들어오므로 새로운 스폰서 이름.
                 
                String create_sponsor_query = "INSERT INTO SPONSOR( SPONSORNAME ) values('"+SPONSORID+"' )";
                stmt.executeUpdate(create_sponsor_query);
                int insertedSonsorID = getLastInsertID(stmt);
                
                // SOPNSOR_LOG 저장 - CREATE
                String prevQuery = selectPreviousInformation(stmt, "SPONSOR_LOG", "SPONSOR", tableSchemaName);
                String logInsertQuery = prevQuery+",'SITE', "+INVID+",'CREATE',NOW() from SPONSOR where SPONSORID="+insertedSonsorID;
                stmt.executeUpdate(logInsertQuery);

                //Get Study ID
                String get_last_insert_sponsor = "SELECT LAST_INSERT_ID();";
                ResultSet rs_sponsor = stmt.executeQuery(get_last_insert_sponsor);
               
                while(rs_sponsor.next()){
                    SPONSORID = ""+rs_sponsor.getInt(1);
                }
            }

             //Creation time setting
            DecimalFormat df = new DecimalFormat("00");
            Calendar calendar = Calendar.getInstance();
            String year = Integer.toString(calendar.get(Calendar.YEAR)); 
            String month = df.format(calendar.get(Calendar.MONTH) + 1); 
            String day = df.format(calendar.get(Calendar.DATE)); 
            String hour = df.format(calendar.get(Calendar.HOUR_OF_DAY));
            String minute = df.format(calendar.get(Calendar.MINUTE));
            String second = df.format(calendar.get(Calendar.SECOND));
            String today = year+"-"+month+"-"+day+" "+hour+":"+minute+":"+second;

            //Create study
            String create_study_query = "INSERT INTO STUDY(INVID, SITEID, SPONSORID, PRTNO, TITLE, SAPPL, SSEX, SNUM, STARGET, SCREATEDTC) values("+INVID+", "+SITEID+", "+SPONSORID+", '"+PRTNO+"', '"+STITLE+"',  '"+SAPPLICANT+"', "+SSEX+", "+SNUM+", '"+STARGET+"', '"+today+"' )";
            if(STARGET.trim().equals("")) create_study_query = "INSERT INTO STUDY(INVID, SITEID, SPONSORID, PRTNO, TITLE, SAPPL, SSEX, SNUM, SCREATEDTC) values("+INVID+", "+SITEID+", "+SPONSORID+", '"+PRTNO+"', '"+STITLE+"',  '"+SAPPLICANT+"', "+SSEX+", "+SNUM+", '"+today+"' )";;

            stmt.executeUpdate(create_study_query);
            int SID = getLastInsertID(stmt);
           
            // STUDY_LOG 저장 - CREATE
            String studyLogPrevQuery = selectPreviousInformation(stmt, "STUDY_LOG", "STUDY", tableSchemaName);
            String studyLogInsertQuery = studyLogPrevQuery+",'SITE', "+INVID+",'CREATE',NOW() from STUDY where SID="+SID;
            // out.print(studyLogInsertQuery);
            stmt.executeUpdate(studyLogInsertQuery);
      
            //save pi 
            String create_study_inv_query = "INSERT INTO STUDY_INV(SID, INVID, SIROLECODE, SIROLETITLE, SIMODIFYROLE, SIRESERVEROLE, SIIDENTITYROLE, SICONSENTROLE, SISIGNROLE) values("+SID+", "+PIID+", 1 ,'시험책임자',1,1,1,1,1)";
            stmt.executeUpdate(create_study_inv_query);
            int SIID = getLastInsertID(stmt);

            // STUDY_INV_LOG 저장 - CREATE
            String studyINVLogPrevQuery = selectPreviousInformation(stmt, "STUDY_INV_LOG", "STUDY_INV", tableSchemaName);
            String studyINVLogInsertQuery = studyINVLogPrevQuery+",'SITE', "+INVID+",'CREATE',NOW() from STUDY_INV where SIID="+SIID;
            stmt.executeUpdate(studyINVLogInsertQuery);

            out.println(SID);
            stmt.close();
            conn.close();
        }

        /*
            Modify Study Info
            Input : SID, PRTNO, SPONSOR, STITLE, SAPPLICANT, SSEX, SNUM, INVID, SITEID
            Output : Null
        */
        else if(type.equals("MODIFY_INFO")){
                      
            //Load Study information
            String SID = request.getParameter("SID");
            String PRTNO = request.getParameter("PRTNO");
            String SPONSORID =  request.getParameter("SPONSORID");
            String SACTIVE =  request.getParameter("SACTIVE");
            String STITLE = request.getParameter("STITLE");
            String SAPPLICANT = request.getParameter("SAPPLICANT");
            String SSEX = request.getParameter("SSEX");
            String SNUM = request.getParameter("SNUM");
            if(SNUM.equals("")) SNUM = "0";
            String STARGET = request.getParameter("STARGET");

            //Protocol No should be unique at a site
            //Check if ProtocolNo exists
            //String check_prtno_exist = "SELECT EXISTS (SELECT * FROM STUDY WHERE PRTNO = '" + PRTNO +"' and SITEID= "+SITEID+" ) AS SUCCESS;";
            String check_prtno_exist = "SELECT count(SID)  FROM study WHERE LOWER(PRTNO) LIKE  '%"+PRTNO+"%' and SITEID="+SITEID + " and SID !="+SID;
            ResultSet prtno_exist_rs = stmt.executeQuery(check_prtno_exist);
            int prtno_exist = 0;
            while(prtno_exist_rs.next()){
                prtno_exist = prtno_exist_rs.getInt(1);
            }
        
            if (prtno_exist>=1){ //return error message
                
                out.println("error 4044 : 동일한 프로토콜의 다른 연구가 존재합니다.");
                stmt.close();
                conn.close();
                return;
            }
              //Sponsor
            /*Check if Sponsor exists-사용자 입력으로 의뢰인 추가시 SPONSORID 가 숫자가 아닌 값이 들어오므로 더이상 필요없음.
            String check_sponsor_exist = "SELECT EXISTS (SELECT * FROM SPONSOR WHERE SPONSORID = '" + SPONSORID +"') AS SUCCESS;";
            ResultSet exist_rs = stmt.executeQuery(check_sponsor_exist);
            int exist = 0;
            while(exist_rs.next()){
                exist = exist_rs.getInt(1);
            }

            //error if Sponsor does not exist
            if (exist==0){
                out.println("error 4045: 목록에 없는 의뢰자입니다. 관리자에게 요청하여 주십시오.");                
                stmt.close();
                conn.close();
                return;
            }*/
            /*check if sponsorid is number or string
             string 인 경우 sponsor table에 새로 추가하고 그 아이디값을 받는다.
            */

            if(!SPONSORID.matches("[0-9]+")){ //string 이 들어오므로 새로운 스폰서 이름.
                 
                String create_sponsor_query = "INSERT INTO SPONSOR( SPONSORNAME ) values('"+SPONSORID+"' )";
                stmt.executeUpdate(create_sponsor_query);
        
                //Get Study ID
                String get_last_insert_sponsor = "SELECT LAST_INSERT_ID();";
                ResultSet rs_sponsor = stmt.executeQuery(get_last_insert_sponsor);
               
                while(rs_sponsor.next()){
                    SPONSORID = ""+rs_sponsor.getInt(1);
                }

                // SPONSOR_LOG 저장 - CREATE
                String sponsorLogPrevQuery = selectPreviousInformation(stmt, "SPONSOR_LOG", "SPONSOR", tableSchemaName);
                String sponsorLogInsertQuery = sponsorLogPrevQuery+",'SITE', "+INVID+",'CREATE',NOW() from SPONSOR where SPONSORID="+SPONSORID;
                stmt.executeUpdate(sponsorLogInsertQuery);

            }
            String ACTIVESTR=", SACTIVE="+SACTIVE;
            if(SACTIVE.equals("0")){
                //Published time setting
                DecimalFormat df = new DecimalFormat("00");
                Calendar calendar = Calendar.getInstance();
                String year = Integer.toString(calendar.get(Calendar.YEAR)); 
                String month = df.format(calendar.get(Calendar.MONTH) + 1); 
                String day = df.format(calendar.get(Calendar.DATE)); 
                String hour = df.format(calendar.get(Calendar.HOUR_OF_DAY));
                String minute = df.format(calendar.get(Calendar.MINUTE));
                String second = df.format(calendar.get(Calendar.SECOND));
                String today = year+"-"+month+"-"+day+" "+hour+":"+minute+":"+second;

                ACTIVESTR=ACTIVESTR+", SCLOSEDTC='"+today+"'";
            }
            String modify_study_query = "UPDATE STUDY SET SPONSORID = "+SPONSORID+", PRTNO = '"+PRTNO+"', TITLE = '"+STITLE+"', SAPPL = '"+SAPPLICANT+"', SSEX = "+SSEX+", SNUM = "+SNUM + ACTIVESTR+", STARGET = '"+STARGET+"' WHERE SID = "+SID;
            stmt.executeUpdate(modify_study_query);

            // STUDY_LOG 저장 - UPDATE
            String studyLogPrevQuery = selectPreviousInformation(stmt, "STUDY_LOG", "STUDY", tableSchemaName);
            String studyLogInsertQuery = studyLogPrevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from STUDY where SID="+SID;
            stmt.executeUpdate(studyLogInsertQuery);

     
            out.println("success");    


            stmt.close();
            conn.close();
        }

        /*
            Update Notice
            Input : SID, SSTAT , SDATE, SILE, SFILENAME, SPUBLISHED, ORDER
            Output : Null
     
        else if(type.equals("UPDATE_NOTICE")){
      
            //Load Study information
            String SID = request.getParameter("SID");
           // String SSTAT = request.getParameter("SSTAT");
            String SDATE = request.getParameter("SDATE");
            String SFILE = request.getParameter("SFILE");
            String SFILENAME = request.getParameter("SFILENAME");
            String SPUBLISHED = request.getParameter("SPUBLISHED");
         

            //Published time setting
            DecimalFormat df = new DecimalFormat("00");
            Calendar calendar = Calendar.getInstance();
            String year = Integer.toString(calendar.get(Calendar.YEAR)); 
            String month = df.format(calendar.get(Calendar.MONTH) + 1); 
            String day = df.format(calendar.get(Calendar.DATE)); 
            String hour = df.format(calendar.get(Calendar.HOUR_OF_DAY));
            String minute = df.format(calendar.get(Calendar.MINUTE));
            String second = df.format(calendar.get(Calendar.SECOND));
            String today = year+"-"+month+"-"+day+" "+hour+":"+minute+":"+second;

            //Update Notice
            String update_notice_query = "";
            switch(SPUBLISHED){
                case "2":
                    if(SFILE.equals("")) update_notice_query = "UPDATE STUDY SET  SDATE = '"+SDATE+"', SPUBLISHED = "+SPUBLISHED+"  WHERE SID="+SID;
                    else update_notice_query = "UPDATE STUDY SET  SDATE = '"+SDATE+"', SFILE = '"+SFILE+"', SFILENAME = '"+SFILENAME+"', SPUBLISHED = "+SPUBLISHED+" WHERE SID="+SID;
                break;
                case "1":
                    if(SFILE.equals("")) update_notice_query = "UPDATE STUDY SET  SDATE = '"+SDATE+"', SPUBLISHED = "+SPUBLISHED+", SPUBLISHDTC = '"+today+"' WHERE SID="+SID;
                    else update_notice_query = "UPDATE STUDY SET SDATE = '"+SDATE+"', SFILE = '"+SFILE+"', SFILENAME = '"+SFILENAME+"', SPUBLISHED = "+SPUBLISHED+", SPUBLISHDTC = '"+today+"' WHERE SID="+SID;
                break;                
            }
             log("[METORY log]"+"\t||\t[SITEID]="+SITEID+"\t||\t[INVID]="+INVID+"\t||\t[type]="+type+"\t||\t[QUERY]="+update_notice_query.replace("'", "\'"));   
            stmt.executeUpdate(update_notice_query);

            stmt.close();
            conn.close();
        }   */
           
        else if(type.equals("UPDATE_NOTICE")){
      
            //Load Study information
            String SID = request.getParameter("SID");
            String SPUBLISHED = request.getParameter("SPUBLISHED");
         
            //Published time setting
            DecimalFormat df = new DecimalFormat("00");
            Calendar calendar = Calendar.getInstance();
            String year = Integer.toString(calendar.get(Calendar.YEAR)); 
            String month = df.format(calendar.get(Calendar.MONTH) + 1); 
            String day = df.format(calendar.get(Calendar.DATE)); 
            String hour = df.format(calendar.get(Calendar.HOUR_OF_DAY));
            String minute = df.format(calendar.get(Calendar.MINUTE));
            String second = df.format(calendar.get(Calendar.SECOND));
            String today = year+"-"+month+"-"+day+" "+hour+":"+minute+":"+second;

            //Update Notice
            String update_notice_query = "";
            switch(SPUBLISHED){
                case "2":
                    update_notice_query = "UPDATE STUDY SET  SPUBLISHED = "+SPUBLISHED+"  WHERE SID="+SID;
                     break;
                case "1":
                    update_notice_query = "UPDATE STUDY SET  SPUBLISHED = "+SPUBLISHED+", SPUBLISHDTC = '"+today+"' WHERE SID="+SID;
                break;                
            }
            stmt.executeUpdate(update_notice_query);

            // STUDY_LOG 저장 - UPDATE
            String studyLogPrevQuery = selectPreviousInformation(stmt, "STUDY_LOG", "STUDY", tableSchemaName);
            String studyLogInsertquery = studyLogPrevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from STUDY where SID="+SID;
            stmt.executeUpdate(studyLogInsertquery);

            stmt.close();
            conn.close();
        } 
        
         else if(type.equals("SAVE_ADS")){
      
            //Load Study information
            String SID = request.getParameter("SID");
            // String SSTAT = request.getParameter("SSTAT");
            String SDATE = URLDecoder.decode(request.getParameter("SDATE"), "UTF-8");     
            String SFILE = URLDecoder.decode(request.getParameter("SFILE"), "UTF-8");     
            String SFILENAME =URLDecoder.decode(request.getParameter("SFILENAME"), "UTF-8");     
         
            //Published time setting
            DecimalFormat df = new DecimalFormat("00");
            Calendar calendar = Calendar.getInstance();
            String year = Integer.toString(calendar.get(Calendar.YEAR)); 
            String month = df.format(calendar.get(Calendar.MONTH) + 1); 
            String day = df.format(calendar.get(Calendar.DATE)); 
            String hour = df.format(calendar.get(Calendar.HOUR_OF_DAY));
            String minute = df.format(calendar.get(Calendar.MINUTE));
            String second = df.format(calendar.get(Calendar.SECOND));
            String today = year+"-"+month+"-"+day+" "+hour+":"+minute+":"+second;

            //Update Notice
            String update_notice_query = "";
       
            
            if(SFILE.equals("")) update_notice_query = "UPDATE STUDY SET  SDATE = '"+SDATE+"'  WHERE SID="+SID;
            else update_notice_query = "UPDATE STUDY SET  SDATE = '"+SDATE+"', SFILE = '"+SFILE+"', SFILENAME = '"+SFILENAME+"' WHERE SID="+SID;
      
            stmt.executeUpdate(update_notice_query);

            // STUDY_LOG 저장 - UPDATE
            String studyLogPrevQuery = selectPreviousInformation(stmt, "STUDY_LOG", "STUDY", tableSchemaName);
            String studyLogInsertQuery = studyLogPrevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from STUDY where SID="+SID;
            stmt.executeUpdate(studyLogInsertQuery);

            stmt.close();
            conn.close();
        }

        /*
            Update Extra Contents
            Input : INVID, SID, EXTRA_CONTENTS
            Output : Null
        */
        else if(type.equals("UPDATE_EXTRA_CONTENTS")){

            //Setting JSON Parser
            JSONParser parser = new JSONParser();
            
            //Load Study information
            String SID = request.getParameter("SID");
            String extras = request.getParameter("contents");

            //Parse Study extra Contents
            extras = URLDecoder.decode(extras, "UTF-8");
            JSONArray contents = (JSONArray)parser.parse(extras);

            //Delete Extra Contents From Database - step1
            List<Integer> SDIDarr = new ArrayList();
            String selectSDIDquery = "select SDID from study_detail where SID="+SID;
            ResultSet rs = stmt.executeQuery(selectSDIDquery);
            while(rs.next()) SDIDarr.add(rs.getInt(1));
            
            //Delete Extra Contents From Database - step2
            String delete_extra_query = "DELETE FROM STUDY_DETAIL WHERE SID = "+SID;
            stmt.executeUpdate(delete_extra_query);

            // STUDY_DETAIL_LOG 저장 - DELETE
            for(int idx=0; idx<SDIDarr.size(); idx++){
                String studyDetailLogInsertQuery = "INSERT INTO study_detail_log(SDID, WHO, WHO_ID, HOW, LOGDTC) values("+SDIDarr.get(idx)+",'SITE',"+INVID+",'DELETE', NOW())";
                stmt.executeUpdate(studyDetailLogInsertQuery);
            }

            //Insert Extra Contents
            for(int i = 0; i < contents.size(); i++){
                JSONObject content = (JSONObject)contents.get(i);
                String SDTITLE = String.valueOf(content.get("title"));
                String SDCONTENT = String.valueOf(content.get("content"));
                
                String insert_extra_query = "INSERT INTO STUDY_DETAIL(SID, INVID, SDTITLE, SDCONTENT) values("+SID+", "+INVID+", '"+SDTITLE+"', '"+SDCONTENT+"')";
                stmt.executeUpdate(insert_extra_query);
                int insertedSDID = getLastInsertID(stmt);

                // STUDY_DETAIL_LOG 저장 - CREATE
                String studyDetailLogPrevQuery = selectPreviousInformation(stmt, "STUDY_DETAIL_LOG", "STUDY_DETAIL", tableSchemaName);
                String studyDetailLogInsertquery = studyDetailLogPrevQuery+",'SITE', "+INVID+",'CREATE',NOW() from STUDY_DETAIL where SDID="+insertedSDID;
                stmt.executeUpdate(studyDetailLogInsertquery);

            }

            stmt.close();
            conn.close();
        }
        
        /*
            Create Consent Group
            Input : SITEID, SID, CSGRPTITLE, CSGRPTYPE
            Output : Null
        */
        else if(type.equals("CREATE_CONSENT_GROUP")){

            //Load Study information
            String SID = request.getParameter("SID");
            String CSGRPTITLE = request.getParameter("CSGRPTITLE");
            String CSGRPTYPE = request.getParameter("CSGRPTYPE");

            //Create Consent
            String create_consent_group_query = "INSERT INTO CONSENT_GROUP(SID, SITEID, CSGRPTITLE, CSGRPTYPE) values("+SID+", "+SITEID+", '"+CSGRPTITLE+"', "+CSGRPTYPE+")";
            stmt.executeUpdate(create_consent_group_query);
            int insertedCSGRPID = getLastInsertID(stmt);

            // CONSENT_GROUP_LOG 저장 - CREATE
            String consentGroupLogPrevQuery = selectPreviousInformation(stmt, "CONSENT_GROUP_LOG", "CONSENT_GROUP", tableSchemaName);
            String consentGroupLogInsertQuery = consentGroupLogPrevQuery+",'SITE', "+INVID+",'CREATE',NOW() from CONSENT_GROUP where CSGRPID="+insertedCSGRPID;
            stmt.executeUpdate(consentGroupLogInsertQuery);

            stmt.close();
            conn.close();
            
        }

        /*
            Create Consent
            Input : INVID, SITEID, SID, CVERSION, CFILE, CFILENAME,ISPUBLISH, CONTACT_COPTION, INV_SIGN_COPTION
            Output : CONSENTID
        */
        else if(type.equals("CREATE_CONSENT")){

            //Load Study information
            String SID = request.getParameter("SID");
            String CVERSION = URLDecoder.decode(request.getParameter("CVERSION"), "UTF-8");
     
            String CFILE = URLDecoder.decode(request.getParameter("CFILE"), "UTF-8");
            String CFILENAME = URLDecoder.decode(request.getParameter("CFILENAME"), "UTF-8");
            String ISPUBLISH = request.getParameter("ISPUBLISH");
            String CSGRPID = request.getParameter("CSGRPID");
            String CONTACT_COPTION = request.getParameter("CONTACT_COPTION");
            String INV_SIGN_COPTION = request.getParameter("INV_SIGN_COPTION");
            String CFILE_HASH = URLDecoder.decode(request.getParameter("CFILE_HASH"), "UTF-8");

            //Creation time setting
            DecimalFormat df = new DecimalFormat("00");
            Calendar calendar = Calendar.getInstance();
            String year = Integer.toString(calendar.get(Calendar.YEAR)); 
            String month = df.format(calendar.get(Calendar.MONTH) + 1); 
            String day = df.format(calendar.get(Calendar.DATE)); 
            String hour = df.format(calendar.get(Calendar.HOUR_OF_DAY));
            String minute = df.format(calendar.get(Calendar.MINUTE));
            String second = df.format(calendar.get(Calendar.SECOND));
            String today = year+"-"+month+"-"+day+" "+hour+":"+minute+":"+second;
            int contact=0;
            int uncontact=0;
            if(CVERSION.equals("")) CVERSION = today;
            if (CONTACT_COPTION.equals("1")) contact=1;
            else uncontact=1;
            
            int update_consent=0; //동의서가 update된 경우(재동의) 1로 표시



                ////////////시작     /* 게시일을 저장하여 게시일로부터 최근의 동의서를 가져오므로 더이상 필요없음.//////
             //새로운 consent가 개시 된 경우 기존의 가장 최근 동의서 표시를 리셋한다.
            /* if(ISPUBLISH.equals("1")){
               //RESET the RECENT_PUBLISHED  on old consent
                //String update_query =  "UPDATE CONSENT SET RECENT_PUBLISHED =0 WHERE RECENT_PUBLISHED =1 and  SID = "+SID +" and CSGRPID="+CSGRPID +" ";
               String update_query =  "UPDATE CONSENT SET RECENT_PUBLISHED =0 WHERE RECENT_PUBLISHED =1 and  SID = "+SID +" and CSGRPID="+CSGRPID ;
                stmt.executeUpdate(update_query);     
             } */
           //////////// 종료   /* 게시일을 저장하여 게시일로부터 최근의 동의서를 가져오므로 더이상 필요없음.//////
            //Create Consent

            String update_consent_query ="";
            if (ISPUBLISH.equals("1"))     update_consent_query = "INSERT INTO CONSENT(SID, SITEID, INVID, CFILE, CFILENAME, CVERSION, CPUBLISHDTC, ISPUBLISH, CSGRPID,CONTACT_COPTION, INV_SIGN_COPTION,  CFILE_HASH) values("+SID+", "+SITEID+", "+INVID+", '"+CFILE+"', '"+CFILENAME+"', '"+CVERSION+"', '"+today+"',"+ISPUBLISH+", "+CSGRPID+","+CONTACT_COPTION+","+INV_SIGN_COPTION+",'"+CFILE_HASH+"')";        
            else          
            update_consent_query = "INSERT INTO CONSENT(SID, SITEID, INVID, CFILE, CFILENAME, CVERSION, CSGRPID,CONTACT_COPTION, INV_SIGN_COPTION,  CFILE_HASH) values("+SID+", "+SITEID+", "+INVID+", '"+CFILE+"', '"+CFILENAME+"', '"+CVERSION+"', "+CSGRPID+","+CONTACT_COPTION+","+INV_SIGN_COPTION+",'"+CFILE_HASH+"')";
            stmt.executeUpdate(update_consent_query);
            int CONSENTID = getLastInsertID(stmt);

            // CONSENT_LOG 저장 - CREATE
            String consentLogPrevQuery = selectPreviousInformation(stmt, "CONSENT_LOG", "CONSENT", tableSchemaName);
            String consentLogInsertQuery = consentLogPrevQuery+",'SITE', "+INVID+",'CREATE',NOW() from CONSENT where CONSENTID="+CONSENTID;
            stmt.executeUpdate(consentLogInsertQuery);

          
            // 연구에 참여중인 모든 대상자에 한해 이 동의서에 대한 정보를 consent_subject 에 생성해야한다.
            if(ISPUBLISH.equals("1")){
                String query_select_ongoing_subject = "select sa.SAID  from  study_applicant sa where  SID = "+SID+" and sa.SAACTIVE = 1";
                // String query_select_ongoing_subject = "select sa.SAID, IFNULL(ap.APPOINTID,0) as appointid  from study_applicant sa left join appointment ap on sa.SAID=ap.SAID where  sa.SID =  "+SID+" and sa.SAACTIVE = 1 and ap.identifydtc is null and ap.appointdtc >=now() ";
                ResultSet rs_ongoing = stmt.executeQuery(query_select_ongoing_subject);           
                Statement stmt2 =null;
                Statement stmt3 =null;
                try{
                    stmt2 = conn.createStatement();
                    stmt3 = conn.createStatement();

                    while(rs_ongoing.next()){

                        String query_appointment = "select count(SAID) as count, IFNULL(APPOINTID,0) as appointid  from appointment  where  SAID =  "+rs_ongoing.getInt(1)+"  and identifydtc is null and appointdtc >=now() order by APPOINTID DESC LIMIT 1";
                        ResultSet rs_appointment = stmt3.executeQuery(query_appointment);       
                        int appointid=0;
                        while(rs_appointment.next()){
                            if(rs_appointment.getInt("count")>0) appointid=rs_appointment.getInt("appointid") ;
                        }

                        String query_said_insert="";

                        if(appointid>0){
                            query_said_insert = "insert into consent_subject(SAID, CONSENTID, SITEID, CS_CONTACT_STAGE, CS_UNCONTACT_STAGE, APPOINTID) values("+rs_ongoing.getInt(1)+", "+CONSENTID+", "+SITEID+","+contact+","+uncontact+","+appointid+");";
                        }
                        else {
                            query_said_insert = "insert into consent_subject(SAID, CONSENTID, SITEID, CS_CONTACT_STAGE, CS_UNCONTACT_STAGE) values("+rs_ongoing.getInt(1)+", "+CONSENTID+", "+SITEID+","+contact+","+uncontact+");";
                        }
                        stmt2.executeUpdate(query_said_insert);
                        int insertedCSID = getLastInsertID(stmt2);
                        
                        // CONSENT_SUBJECT_LOG 저장 - CREATE
                        String consentSubjectLogPrevQuery = selectPreviousInformation(stmt2, "CONSENT_SUBJECT_LOG", "CONSENT_SUBJECT", tableSchemaName);
                        String consentSubjectLogInsertQuery = consentSubjectLogPrevQuery+",'SITE', "+INVID+",'CREATE',NOW() from CONSENT_SUBJECT where CSID="+insertedCSID;
                        stmt2.executeUpdate(consentSubjectLogInsertQuery);
                    }
                }catch(Exception e){
                    e.printStackTrace();
                }
                finally{
                    if(stmt2!=null)   stmt2.close();
                    if(stmt3!=null)   stmt3.close();
                }
           }

           out.println(CONSENTID);
            stmt.close();
            conn.close();
            
        }
          else if(type.equals("save_multi_sms_log")){      
            String RECEIPTNUM = request.getParameter("RECEIPTNUM");
            String SID = request.getParameter("SID");     
            String saids = request.getParameter("saids");           
            String CONSENTID = request.getParameter("CONSENTID");
            String phonenum = URLDecoder.decode(request.getParameter("phonenum"),"UTF-8");
            String message = URLDecoder.decode(request.getParameter("message"),"UTF-8");
            String receivers = URLDecoder.decode(request.getParameter("receivers"),"UTF-8");
   

            DecimalFormat df = new DecimalFormat("00");
            Calendar calendar = Calendar.getInstance();
            String year = Integer.toString(calendar.get(Calendar.YEAR)); 
            String month = df.format(calendar.get(Calendar.MONTH) + 1); 
            String day = df.format(calendar.get(Calendar.DATE)); 
            String hour = df.format(calendar.get(Calendar.HOUR_OF_DAY));
            String minute = df.format(calendar.get(Calendar.MINUTE));
            String second = df.format(calendar.get(Calendar.SECOND));        
            String today = year+"-"+month+"-"+day+" "+hour+":"+minute+":"+second;

            out.println(phonenum+"\treceiver_name="+receivers+"\t"+saids);
           
             String[] phonenumarr=phonenum.split(",");
             String[] receiverarr=receivers.split(",");
             String[] saidarr=saids.split(",");
             out.println(" length==" + receiverarr.length);

              for(int i=0; i< receiverarr.length ; i++){
           
               String insert_query = "INSERT INTO smslog(sms_receipt_num, sender_id, siteid, sid, receiver_name, receiver_phone, message, senddtc, said,server, sms_action_type ) values('"+RECEIPTNUM+"',"+INVID+","+SITEID+","+SID+",'"+receiverarr[i]+"','"+phonenumarr[i]+"','"+message+"','"+today+"',"+saidarr[i]+",'site','멀티문자발송')";
           
                stmt.executeUpdate(insert_query);  
             } 
  


            stmt.close();
            conn.close();
            out.println("SUCCESS");
        }
         /*
            Update Consent
            Input : CONSENTID, CVERSION, CFILE, CFILENAME, ISPUBLISH, CONTACT_COPTION, INV_SIGN_COPTION
            Output : "success"
        */
        else if(type.equals("GET_SAACTIVE_LIST")){
      
            //Load Study information
            String CONSENTID = request.getParameter("CONSENTID");          
            String SID = request.getParameter("SID");

              JSONArray subjlist = new JSONArray();
            
          
               
            //check 연구가 진행중인지.
            String ongoing_study_query = "SELECT SACTIVE FROM  study where SID = "+SID;
            ResultSet ongoing_study_rs = stmt.executeQuery(ongoing_study_query); 
            int ongoing_study=0;          
            while(ongoing_study_rs.next()){
                 ongoing_study   = ongoing_study_rs.getInt("SACTIVE");
             }

            // consent가 개시 된 경우 연구에 참여중인 모든 대상자에 한해 consent_subject 에 저장한다.          
            String ongoing_subject_query = "SELECT a.APPLNAME, a.APPLPHONENUM, sa.applid, sa.said, cs.CSID, sa.SAACTIVE , cs.CONSENTID , sa.SID FROM  applicant a, consent_subject cs, study_applicant sa  WHERE  sa.said=cs.said AND sa.SID="+SID+" AND cs.CONSENTID ="+CONSENTID+" AND sa.SAACTIVE=1 AND sa.APPLID=a.APPLID;";  
            ResultSet ongoing_subject_rs = stmt.executeQuery(ongoing_subject_query);           
            while(ongoing_subject_rs.next()){
                 JSONObject jb =new JSONObject();
                jb.put("APPLPHONENUM", ongoing_subject_rs.getString("a.APPLPHONENUM"));
                jb.put("SACTIVE", ongoing_study);
                jb.put("APPLID",  ongoing_subject_rs.getInt("sa.applid"));
                jb.put("SAID",  ongoing_subject_rs.getInt("sa.said"));
                jb.put("APPLNAME",  ongoing_subject_rs.getString("a.APPLNAME"));
                subjlist.add(jb);
            }  
        


            stmt.close();
            conn.close();
            out.println(subjlist);
            
        }
        /*
            Update Consent
            Input : CONSENTID, CVERSION, CFILE, CFILENAME, ISPUBLISH, CONTACT_COPTION, INV_SIGN_COPTION
            Output : "success"
        */
        else if(type.equals("UPDATE_CONSENT")){
      
            //Load Study information
            String CONSENTID = request.getParameter("CONSENTID");
             String SID = request.getParameter("SID");
            String CVERSION = URLDecoder.decode(request.getParameter("CVERSION"), "UTF-8");     
            String CFILE = URLDecoder.decode(request.getParameter("CFILE"), "UTF-8");
            String CFILENAME = URLDecoder.decode(request.getParameter("CFILENAME"), "UTF-8");
             String ISPUBLISH = request.getParameter("ISPUBLISH");
            String CONTACT_COPTION = request.getParameter("CONTACT_COPTION");
            String INV_SIGN_COPTION = request.getParameter("INV_SIGN_COPTION");
             String CFILE_HASH = URLDecoder.decode(request.getParameter("CFILE_HASH"), "UTF-8");

            //Creation time setting
            DecimalFormat df = new DecimalFormat("00");
            Calendar calendar = Calendar.getInstance();
            String year = Integer.toString(calendar.get(Calendar.YEAR)); 
            String month = df.format(calendar.get(Calendar.MONTH) + 1); 
            String day = df.format(calendar.get(Calendar.DATE)); 
            String hour = df.format(calendar.get(Calendar.HOUR_OF_DAY));
            String minute = df.format(calendar.get(Calendar.MINUTE));
            String second = df.format(calendar.get(Calendar.SECOND));
            String today = year+"-"+month+"-"+day+" "+hour+":"+minute+":"+second;

            if(CVERSION.equals("")) CVERSION = today;
             int contact=0;
            int uncontact=0;
        
            if (CONTACT_COPTION.equals("1")) contact=1;
            else uncontact=1;
            //Update Consent
            String update="";
            if (!CFILENAME.equals("")) update=  ", CFILE = '"+CFILE+"', CFILENAME = '"+CFILENAME+"', CFILE_HASH = '"+CFILE_HASH+"'";
            
            if(ISPUBLISH.equals("1")){
                 update=update+",  ISPUBLISH="+ISPUBLISH+", CPUBLISHDTC = '"+today+"'";                
            } 
           
            String update_consent_query = "UPDATE CONSENT SET  CVERSION = '"+CVERSION+ "',CONTACT_COPTION="+CONTACT_COPTION+",INV_SIGN_COPTION="+INV_SIGN_COPTION+ update+"  WHERE CONSENTID = "+CONSENTID;
            stmt.executeUpdate(update_consent_query);       
            String consentLogPrevQuery = selectPreviousInformation(stmt, "CONSENT_LOG", "CONSENT", tableSchemaName);
            String consentLogInsertQuery = consentLogPrevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from CONSENT where CONSENTID="+CONSENTID;
            stmt.executeUpdate(consentLogInsertQuery);


            // consent가 개시 된 경우 연구에 참여중인 모든 대상자에 한해 consent_subject 에 저장한다.
           if(ISPUBLISH.equals("1")){
                String query_select_ongoing_subject = "select SAID from  study_applicant where SID = "+SID+" and SAACTIVE = 1";
                ResultSet rs_ongoing = stmt.executeQuery(query_select_ongoing_subject);           
                Statement stmt2 =null;
 
                try{
                    stmt2 = conn.createStatement();

                    while(rs_ongoing.next()){
                        String query_said_insert = "insert into consent_subject(SAID, CONSENTID, SITEID, CS_CONTACT_STAGE, CS_UNCONTACT_STAGE) values("+rs_ongoing.getInt(1)+", "+CONSENTID+", "+SITEID+","+contact+","+uncontact+");";
                        stmt2.executeUpdate(query_said_insert);              
                        int insertedCSID = getLastInsertID(stmt2);
                        String consentSubjectLogPrevQuery = selectPreviousInformation(stmt2, "CONSENT_SUBJECT_LOG", "CONSENT_SUBJECT", tableSchemaName);
                        String consentSubjectLogInsertQuery = consentSubjectLogPrevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from CONSENT_SUBJECT where CSID="+insertedCSID;
                        stmt2.executeUpdate(consentSubjectLogInsertQuery);
                    }
                }catch(Exception e){
                    e.printStackTrace();
                }
                finally{
                    if(stmt2!=null)       stmt2.close();
                }
           }


            stmt.close();
            conn.close();
            out.println("success");
            
        }

        /*
            Update Sign Form
            Input : CONSENTID, Sign Form Contents
            Output : Null
        */
        else if(type.equals("UPDATE_SIGN_FORM")){
            //Setting JSON Parser
            JSONParser parser = new JSONParser();
            
            //Load Study information
            String CONSENTID = request.getParameter("CONSENTID");
            String extras = request.getParameter("contents");

            //Parse Sign Forms
            extras = URLDecoder.decode(extras, "UTF-8");
            JSONArray contents = (JSONArray)parser.parse(extras);

            //Delete Sign Forms From Database - step1
            String selectCDIDquery = "select CDID from CONSENT_DETAIL where CONSENTID="+CONSENTID;
            ResultSet rs = stmt.executeQuery(selectCDIDquery);
            List<Integer> CDIDarr = new ArrayList(); // 지워질 CDID 저장 Array
            while(rs.next()){
                CDIDarr.add(rs.getInt(1));
            }
            
            //Delete Sign Forms From Database - step2
            String delete_extra_query = "DELETE FROM CONSENT_DETAIL WHERE CONSENTID = "+CONSENTID;
            stmt.executeUpdate(delete_extra_query);

            //CONSENT_DETAIL_LOG 저장 - DELETE
            for(int idx=0; idx<CDIDarr.size(); idx++){
                String consentDetailLogquery="INSERT INTO CONSENT_DETAIL_LOG(CDID, PAGENUM, MINDURATION, WHO, WHO_ID, HOW, LOGDTC) values("+CDIDarr.get(idx)+",null, null,'SITE',"+INVID+",'DELETE',NOW())";
                stmt.executeUpdate(consentDetailLogquery);
            }

            //Insert Sign Forms
            for(int i = 0; i < contents.size(); i++){
                JSONObject content = (JSONObject)contents.get(i);
                String CDTITLE = String.valueOf(content.get("title"));
                String CDCONTENT = String.valueOf(content.get("content"));
                out.println("1");
                String insert_extra_query = "INSERT INTO CONSENT_DETAIL(CDIDNUM, CONSENTID, CDTITLE, CDCONTENT) values("+i+", "+CONSENTID+", '"+CDTITLE+"', '"+CDCONTENT+"')";
                stmt.executeUpdate(insert_extra_query);
                int insertedCDID = getLastInsertID(stmt);
                out.println("2");
                //CONSENT_DETAIL_LOG 저장 - CREATE
                String consentDetailLogPrevQuery = selectPreviousInformation(stmt, "CONSENT_DETAIL_LOG", "CONSENT_DETAIL", tableSchemaName);
                String consentDetailLogInsertQuery = consentDetailLogPrevQuery+",'SITE', "+INVID+",'CREATE',NOW() from CONSENT_DETAIL where CDID="+insertedCDID;
                stmt.executeUpdate(consentDetailLogInsertQuery);
                out.println("3");
            }

            stmt.close();
            conn.close(); 
        }

        /*
            Load Study list
            Input : SITEID
            Output : Study list(JSON)
        */
        else if(type.equals("LOAD_STUDY_LIST")){
            //Load User information
            int STUDYADMIN=(int)session.getAttribute("STUDYADMINROLE");
            //Load Study List
            //String study_load_query = "SELECT SID, SPONSORID, PRTNO, TITLE, SNUM, SSTAT, SPUBLISHED, ORDERS, BCSTAGE FROM STUDY WHERE SITEID = "+SITEID+" order by SCREATEDTC desc";
             String study_load_query = "";
         
             if(STUDYADMIN==1) {
                study_load_query = "SELECT SID, SPONSORID, PRTNO, TITLE, SNUM,  SPUBLISHED,  BCSTAGE, SACTIVE FROM STUDY WHERE SITEID = "+SITEID+" order by SCREATEDTC desc";
         //study_load_query = "SELECT s.SID, s.SPONSORID, s.PRTNO, s.TITLE, s.SNUM, s.SSTAT, s.SPUBLISHED, s.ORDERS, s.BCSTAGE, si.SIREADROLE, si.SICREATEROLE, si.SIMODIFYROLE, si.SIIDENTITYROLE , si.SIRESERVEROLE, si.SICONSENTROLE , si.SISIGNROLE  FROM STUDY s , STUDY_INV si  WHERE s.SID=si.SID and s.SITEID = "+SITEID+"   order by s.SCREATEDTC desc;";
             }else     study_load_query = "SELECT s.SID, s.SPONSORID, s.PRTNO, s.TITLE, s.SNUM, s.SPUBLISHED,  s.BCSTAGE,  s.SACTIVE  FROM STUDY s , STUDY_INV si  WHERE s.SID=si.SID and s.SITEID = "+SITEID+"  and (si.INVID="+ INVID +" or s.INVID="+INVID+") group by s.SID  order by s.SCREATEDTC desc;";

             ResultSet rs = stmt.executeQuery(study_load_query);

            JSONArray studies = new JSONArray();

            while(rs.next()){
                JSONObject study = new JSONObject();
                int APPLNUM = 0;
               // int CONSENTID = 0;
                int NEWAPPLNUM = 0;

                //Select Last Consent ID
                Statement stmt_consent = conn.createStatement();
             /*   try{
                    String search_consent_query = "SELECT CONSENTID FROM CONSENT WHERE SID=" + rs.getInt(1) +" ORDER BY CONSENTID DESC LIMIT 1";
                    ResultSet rs_consent_query = stmt_consent.executeQuery(search_consent_query);
                    while(rs_consent_query.next()){
                        CONSENTID = rs_consent_query.getInt(1);
                    }
                    stmt_consent.close();
                }catch(Exception  e){
                    stmt_consent.close();
                }
                finally{
                    if(stmt_consent!=null)   stmt_consent.close();
                }
*/
                //Load Number of Applicant
                Statement appl_stmt = conn.createStatement();
                try{
                   // String appl_query = "SELECT COUNT(cs.CSID) FROM CONSENT_SUBJECT cs, STUDY_APPLICANT sa WHERE  cs.SAID = sa.SAID AND CLOSESTAGE not in (9, 10, 13) AND cs.SAID in (SELECT SAID FROM STUDY_APPLICANT WHERE CLOSESTAGE not in (9, 10, 13) AND SID="+rs.getInt(1)+"  ORDER BY SAID desc);";
                    String appl_query =" SELECT  COUNT(SAID) FROM STUDY_APPLICANT WHERE SASTAGE not in (7,8,9) AND SID="+rs.getInt(1)+"  ORDER BY SAID desc";
                    ResultSet appl_rs = appl_stmt.executeQuery(appl_query);
                    while(appl_rs.next()){
                        APPLNUM = appl_rs.getInt(1);
                    }
                    
                    //Check new Applicant exists
                    /*String appl_new_query = "SELECT COUNT(SA.SAID) FROM STUDY S, STUDY_APPLICANT SA WHERE S.SID = SA.SID  AND SA.SID = "+rs.getInt(1)+" GROUP BY SA.SID;";
                    ResultSet new_appl_rs = appl_stmt.executeQuery(appl_new_query);
                    while(new_appl_rs.next()){
                        NEWAPPLNUM = new_appl_rs.getInt(1);
                    } */
                    appl_stmt.close();
                }catch(Exception e){
                    appl_stmt.close();
                }
                finally{
                    if(appl_stmt!=null)   appl_stmt.close();
                }

                study.put("SID", rs.getInt(1));
                study.put("SPONSOR", rs.getInt(2));
                study.put("PRTNO", rs.getString(3));
                study.put("TITLE", rs.getString(4));
                study.put("APPLNUM", APPLNUM);
                //study.put("NEWAPPLNUM", NEWAPPLNUM);
                study.put("SNUM", rs.getInt(5));
             
                study.put("SPUBLISHED", rs.getInt(6));
               //study.put("EMERGENCY", rs.getInt(7));
                study.put("BCSTAGE", rs.getInt(7));
                 study.put("SACTIVE", rs.getInt(8));

               


               /* if(STUDYADMIN==1)   {
           

                    study.put("SIMODIFY",1);
                    study.put("SIIDENTITYROLE", 1);
                    study.put("SIRESERVEROLE", 1);
                    study.put("SICONSENTROLE", 1);
                    study.put("SISIGNROLE",1);
                
                }
                else {
         
                    study.put("SIMODIFY", rs.getInt(10));        
                    study.put("SIIDENTITYROLE", rs.getInt(11));
                    study.put("SIRESERVEROLE",  rs.getInt(12));
                    study.put("SICONSENTROLE",  rs.getInt(13));
                    study.put("SISIGNROLE", rs.getInt(14));

                } */

                studies.add(study);

            }
    
            stmt.close();
            conn.close();
            out.println(studies);
        }
        
        /*
            Load study Group
            Input : SID
            Output : study Group list(JSON)
        */
        else if(type.equals("LOAD_STUDY_GROUP")){

            String SID = request.getParameter("SID");
            JSONArray grouplist = new JSONArray();

            //Load study group
            String load_study_group_query = "SELECT CSGRPID, CSGRPTITLE, CSGRPTYPE FROM Consent_group where SID ="+SID+" and SITEID = "+SITEID;
            ResultSet rs = stmt.executeQuery(load_study_group_query);
            
            while(rs.next()){
                JSONObject groupdata = new JSONObject();
                groupdata.put("CSGRPID", rs.getInt(1));
                groupdata.put("CSGRPTITLE", rs.getString(2));
                groupdata.put("CSGRPTYPE", rs.getString(3));

                Statement stmt1 = conn.createStatement();
                String load_study_group_consent_query = "SELECT CVERSION, DATE_FORMAT(CPUBLISHDTC,'%Y-%m-%d') as CPUBLISHDTC1,  CFILE_HASH, CONSENTID FROM CONSENT WHERE ISPUBLISH=1 and CSGRPID = "+rs.getInt(1)+" order by CPUBLISHDTC DESC LIMIT 1";
                //String load_study_group_consent_query = "SELECT CVERSION, , ISPUBLISH FROM CONSENT WHERE CSGRPID = "+rs.getInt(1)+" order by CONSENTID DESC LIMIT 1";
                ResultSet rs1= stmt1.executeQuery(load_study_group_consent_query);
                while(rs1.next()){
                    groupdata.put("CSLASTVERSION", rs1.getString(1));
                    groupdata.put("CSLASTVERSIONDATE", rs1.getString("CPUBLISHDTC1"));            
                    groupdata.put("CSLASTVERSIONCFILEHASH", rs1.getString("CFILE_HASH"));
                    groupdata.put("CSLASTVERSIONCONSENTID", rs1.getInt("CONSENTID"));
                }

                stmt1.close();
                grouplist.add(groupdata);
            }

            stmt.close();
            conn.close();
            out.println(grouplist);
        }


        /*
            Load Study Info
            Input : SID
            Output : Study info(JSON)
        */
        else if(type.equals("LOAD_STUDY_INFO")){

            JSONArray studies = new JSONArray();
            int sponsorId=0;
           // String SPONSORNAME="";

            //Load Study information
            String SID = request.getParameter("SID");

            //Load Study info


            String load_study_detail_query = "SELECT  SPONSORID, PRTNO, TITLE,  SPUBLISHED , SNUM, STARGET,  SSEX, SAPPL, BCSTAGE, SCLOSEDTC, SACTIVE, SMS_RECEIVER, USE_APPOINTMENT FROM STUDY WHERE SID = " + SID + "  and SITEID="+SITEID;
            ResultSet rs = stmt.executeQuery(load_study_detail_query);
            JSONObject study = new JSONObject();
            
            while(rs.next()){
              
                sponsorId=rs.getInt(1);
                study.put("PRTNO", rs.getString(2));
                study.put("TITLE", rs.getString(3));
                //study.put("SSTAT", rs.getInt(4));
                study.put("SPUBLISHED", rs.getInt(4));
                study.put("SNUM", rs.getInt(5));
                study.put("STARGET", rs.getString(6));
                study.put("SSEX", rs.getInt(7));
                study.put("SAPPL", rs.getString(8));
                study.put("BCSTAGE", rs.getInt(9)); 
                study.put("SCLOSEDTC", rs.getString(10));  
                study.put("SACTIVE", rs.getInt(11));   
                study.put("SMS_RECEIVER", rs.getString(12))   ;
                study.put("USE_APPOINTMENT", rs.getInt("USE_APPOINTMENT"))   ;         
              }             
           
            String sponsor_name_query = "SELECT SPONSORNAME FROM SPONSOR WHERE SPONSORID = " + sponsorId;
            ResultSet sponsor_name_rs = stmt.executeQuery(sponsor_name_query);
            while(sponsor_name_rs.next()){
                 study.put("SPONSORNAME", sponsor_name_rs.getString(1));                 
            }          

            study.put("SPONSORID", sponsorId);  

            //informed consent 그룹에서 가장 최신의 consent 찾기

            String query_consent="SELECT c.CVERSION, cg.CSGRPTITLE, c.CONSENTID FROM CONSENT c ,CONSENT_GROUP cg WHERE c.ISPUBLISH =1 and c.SID = "+SID+" and c.CSGRPID=cg.CSGRPID and cg.CSGRPTYPE=1 order by c.CPUBLISHDTC  DESC LIMIT 1";
            ResultSet rs_consent = stmt.executeQuery(query_consent);

            while(rs_consent.next()){       
                study.put("CVERSION", rs_consent.getString(1));  
                study.put("CSGRPTITLE", rs_consent.getString(2));     
                study.put("CONSENTID", rs_consent.getInt(3));              
            }

            //search PI
            String load_study_invs_query = "SELECT si.INVID, si.SIROLETITLE, si.SIROLECODE, i.INVNAME FROM STUDY_INV si , INVESTIGATOR i WHERE SID = " + SID +" and si.INVID= i.INVID and i.SITEID="+SITEID + " and si.SIROLECODE=1";
            ResultSet inv_rs = stmt.executeQuery(load_study_invs_query);
            JSONArray invs = new JSONArray();
      
            while(inv_rs.next()){                
                study.put("PIID", inv_rs.getInt(1));  
                study.put("PINAME", inv_rs.getString(4));                  
                 
            }
            studies.add(study);

            stmt.close();
            conn.close();
            out.println(studies);           
        }

         else if(type.equals("LOAD_STUDY_INVS_ALL")){

            //Load Study information
            String SID = request.getParameter("SID");

            //Load Study invs
            String load_study_invs_query = "SELECT si.INVID, si.SIROLETITLE, si.SIROLECODE,  si.SIMODIFYROLE, si.SIRESERVEROLE, si.SIIDENTITYROLE, si.SICONSENTROLE, si.SISIGNROLE, i.INVNAME, si.SIID , i.ACTIVE, i.INACTIVEDATE FROM STUDY_INV si , INVESTIGATOR i WHERE SID = " + SID +" and si.INVID= i.INVID and i.SITEID="+SITEID + "  order by SIROLECODE asc";
            ResultSet inv_rs = stmt.executeQuery(load_study_invs_query);
            JSONArray invs = new JSONArray();
      
            while(inv_rs.next()){
                JSONObject inv = new JSONObject();
                inv.put("INVID", inv_rs.getInt(1));                
                inv.put("SIROLETITLE", inv_rs.getString(2));
                inv.put("SIROLECODE", inv_rs.getInt(3));
               // inv.put("READ", inv_rs.getInt(4));
                //inv.put("CREATE", inv_rs.getInt(5));
                inv.put("MODIFY", inv_rs.getInt(4));
                inv.put("RESERVE", inv_rs.getInt(5));
                inv.put("IDENTITY", inv_rs.getInt(6));
                inv.put("CONSENT", inv_rs.getInt(7));  
                inv.put("SIGN", inv_rs.getInt(8));         
                inv.put("INVNAME", inv_rs.getString(9));     
                inv.put("SIID", inv_rs.getInt(10));     
                inv.put("ACTIVE", inv_rs.getInt(11));      
                inv.put("INACTIVEDATE", inv_rs.getString(12));                   
                invs.add(inv);    
            }


            stmt.close();
            conn.close();
            out.println(invs); 
        }    
        /*
        * 한 명의 연구자의 해당 연구 권한 조회, 
        * 연구에 참여중이 아닌경우, default 권한 값을 role 테이블에서 조회
        */
         else if(type.equals("LOAD_STUDY_INV")){
         
            //Load Study information
             String SID = request.getParameter("SID");
             String ID = request.getParameter("ID");

            //check a invid is already joined this study         
            String check_aInv_exist =   "SELECT COUNT(INVID) FROM STUDY_INV  WHERE SID = " + SID + " and INVID="+ ID;
    
            ResultSet exist_rs = stmt.executeQuery(check_aInv_exist);
            int exist = 0;
            while(exist_rs.next()){
                exist = exist_rs.getInt(1);
            }

                JSONArray invs = new JSONArray();  
           
            if(exist==1) {//already joined so return the inv info
            //Load Study invs
              String load_study_inv_query = "SELECT si.INVID, si.SIROLETITLE, si.SIROLECODE, si.SIREADROLE, si.SICREATEROLE, si.SIMODIFYROLE, si.SIRESERVEROLE, si.SIIDENTITYROLE, si.SICONSENTROLE, si.SISIGNROLE, i.INVNAME FROM STUDY_INV si , INVESTIGATOR i WHERE SID = " + SID +" and si.INVID= i.INVID and i.SITEID="+SITEID + " and si.INVID="+ ID;
                ResultSet inv_rs = stmt.executeQuery(load_study_inv_query);           
               
                while(inv_rs.next()){
              JSONObject inv = new JSONObject();
                    inv.put("INVID", ID);                
                    inv.put("SIROLETITLE", inv_rs.getString(2));
                    inv.put("SIROLECODE", inv_rs.getInt(3));
                    inv.put("READ", inv_rs.getInt(4));
                    inv.put("CREATE", inv_rs.getInt(5));
                    inv.put("MODIFY", inv_rs.getInt(6));
                    inv.put("RESERVE", inv_rs.getInt(7));
                    inv.put("IDENTITY", inv_rs.getInt(8));
                    inv.put("CONSENT", inv_rs.getInt(9));  
                    inv.put("SIGN", inv_rs.getInt(10));         
                    inv.put("INVNAME", inv_rs.getString(11));     
                                   
                 invs.add(inv);    
                }
            } else 
            if (exist==0){// get info from investigator and its group role
              String load_study_inv_query = "SELECT  r.ROLETITLE, r.READROLE, r.CREATEROLE,r.MODIFYROLE, r.RESERVEROLE, r.IDENTITYROLE, r.CONSENTROLE, r.SIGNROLE, i.INVNAME FROM role r , INVESTIGATOR i WHERE r.ROLEID= i.ROLEID and i.SITEID="+ SITEID + " and i.INVID="+ ID;

                ResultSet inv_rs = stmt.executeQuery(load_study_inv_query);
          //out.println(load_study_inv_query);
               
               while(inv_rs.next()){
                    JSONObject inv = new JSONObject();
                    inv.put("INVID", ID);                
                    inv.put("SIROLETITLE", inv_rs.getString(1));
                    inv.put("SIROLECODE", 3); // not pi , and not sub-i
                    inv.put("READ", inv_rs.getInt(2));
                    inv.put("CREATE", inv_rs.getInt(3));
                    inv.put("MODIFY", inv_rs.getInt(4));
                    inv.put("RESERVE", inv_rs.getInt(5));
                    inv.put("IDENTITY", inv_rs.getInt(6));
                    inv.put("CONSENT", inv_rs.getInt(7));  
                    inv.put("SIGN", inv_rs.getInt(8));         
                    inv.put("INVNAME", inv_rs.getString(9));     
                   invs.add(inv);
                }
            }

            stmt.close();
            conn.close();
            out.println(invs);
        
        }    
  
         else if(type.equals("SAVE_INV_TO_STUDY")){
         
            //Load Study information
             String SID = request.getParameter("SID");
             String INVID_TO_SAVE = request.getParameter("ID");

            //check a invid is already joined this study         
            String check_aInv_exist =   "SELECT COUNT(INVID) FROM STUDY_INV  WHERE SID = " + SID + " and INVID="+ INVID_TO_SAVE;
    
            ResultSet exist_rs = stmt.executeQuery(check_aInv_exist);
            int exist = 0;
            while(exist_rs.next()){
                exist = exist_rs.getInt(1);
            }

                JSONArray invs = new JSONArray();  
           
            if(exist==1) {//already joined so return the inv info
            //Load Study invs
              String load_study_inv_query = "SELECT si.INVID, si.SIROLETITLE, si.SIROLECODE, si.SIREADROLE, si.SICREATEROLE, si.SIMODIFYROLE, si.SIRESERVEROLE, si.SIIDENTITYROLE, si.SICONSENTROLE, si.SISIGNROLE, i.INVNAME FROM STUDY_INV si , INVESTIGATOR i WHERE SID = " + SID +" and si.INVID= i.INVID and i.SITEID="+SITEID + " and si.INVID="+ INVID_TO_SAVE;
                ResultSet inv_rs = stmt.executeQuery(load_study_inv_query);           
               
                while(inv_rs.next()){
              JSONObject inv = new JSONObject();
                    inv.put("INVID", INVID_TO_SAVE);                
                    inv.put("SIROLETITLE", inv_rs.getString(2));
                    inv.put("SIROLECODE", inv_rs.getInt(3));
                    inv.put("READ", inv_rs.getInt(4));
                    inv.put("CREATE", inv_rs.getInt(5));
                    inv.put("MODIFY", inv_rs.getInt(6));
                    inv.put("RESERVE", inv_rs.getInt(7));
                    inv.put("IDENTITY", inv_rs.getInt(8));
                    inv.put("CONSENT", inv_rs.getInt(9));  
                    inv.put("SIGN", inv_rs.getInt(10));         
                    inv.put("INVNAME", inv_rs.getString(11));     
                                   
                 invs.add(inv);    
                }
            } else 
            if (exist==0){// get info from investigator and its group role
              String load_study_inv_query = "SELECT  r.ROLETITLE, r.READROLE, r.CREATEROLE,r.MODIFYROLE, r.RESERVEROLE, r.IDENTITYROLE, r.CONSENTROLE, r.SIGNROLE, i.INVNAME FROM role r , INVESTIGATOR i WHERE r.ROLEID= i.ROLEID and i.SITEID="+ SITEID + " and i.INVID="+ INVID_TO_SAVE;

                ResultSet inv_rs = stmt.executeQuery(load_study_inv_query);
          //out.println(load_study_inv_query);
               
               while(inv_rs.next()){
                    JSONObject inv = new JSONObject();
                    inv.put("INVID", INVID_TO_SAVE);                
                    inv.put("SIROLETITLE", inv_rs.getString(1));
                    inv.put("SIROLECODE", 3); // not pi , and not sub-i
                    inv.put("READ", inv_rs.getInt(2));
                    inv.put("CREATE", inv_rs.getInt(3));
                    inv.put("MODIFY", inv_rs.getInt(4));
                    inv.put("RESERVE", inv_rs.getInt(5));
                    inv.put("IDENTITY", inv_rs.getInt(6));
                    inv.put("CONSENT", inv_rs.getInt(7));  
                    inv.put("SIGN", inv_rs.getInt(8));         
                    inv.put("INVNAME", inv_rs.getString(9));     
                   invs.add(inv);
                }
            }

            stmt.close();
            conn.close();
            out.println(invs);
        
        }    
        /*
        * 해당 연구에서의 참여중인 연구자의 권한 조회, 
        * STUDYADMIN 권한자인 경우 참여중으로 본다.
        */
        else if(type.equals("LOAD_STUDY_ROLE")){
                
            String SID = request.getParameter("SID");        
            String INVNAME =   session.getAttribute("INVNAME").toString();
            int STUDYADMIN=(int)session.getAttribute("STUDYADMINROLE");
            JSONArray invs = new JSONArray();             
            if(STUDYADMIN==1) {
                JSONObject inv = new JSONObject();
                inv.put("SIRESERVE", 1);
                inv.put("SIIDENTITY", 1);
                inv.put("SICONSENT", 1);  
                inv.put("SISIGN", 1);      
                       inv.put("INVNAME", INVNAME );    
                   inv.put("INVID", INVID);    
                    inv.put("STUDYADMIN", STUDYADMIN); 
                         
                invs.add(inv);    
                
            } 
            else{
                //Load Study invs
                String load_study_inv_query = "SELECT  si.SIRESERVEROLE, si.SIIDENTITYROLE, si.SICONSENTROLE, si.SISIGNROLE, i.INVNAME FROM STUDY_INV si , INVESTIGATOR i WHERE SID = " + SID +" and si.INVID= i.INVID and i.SITEID="+SITEID + " and si.INVID="+ INVID;
                ResultSet inv_rs = stmt.executeQuery(load_study_inv_query);           
                
                while(inv_rs.next()){
                    JSONObject inv = new JSONObject();
                    inv.put("INVID", INVID);    
                    inv.put("STUDYADMIN", STUDYADMIN); 
                   
                        inv.put("SIRESERVE", inv_rs.getInt(1));
                        inv.put("SIIDENTITY", inv_rs.getInt(2));
                        inv.put("SICONSENT", inv_rs.getInt(3));  
                        inv.put("SISIGN", inv_rs.getInt(4));      
                    
                    
            
                    inv.put("INVNAME", inv_rs.getString(5));                 
                            invs.add(inv);    
                    
                } 

                stmt.close();
                conn.close();
              
            }
      
                    
            out.println(invs);

        }
        else if(type.equals("LOAD_STUDY_NOTICE")){

            //Load Study information
            String SID = request.getParameter("SID");

            //Load Study Notice
            String load_study_notice_query = "SELECT SDATE, SFILE, SFILENAME,  SPUBLISHED FROM STUDY WHERE SID = " + SID;
            ResultSet notice_rs = stmt.executeQuery(load_study_notice_query);
            JSONArray studies = new JSONArray();

            while(notice_rs.next()){
                JSONObject study = new JSONObject();
                study.put("SDATE", notice_rs.getString(1));
                study.put("CONTEXTPATH",  request.getContextPath());             
                study.put("SFILE", notice_rs.getString(2));
                study.put("SFILENAME", notice_rs.getString(3));               
                study.put("SPUBLISHED", notice_rs.getInt(4));
               // study.put("EMERGENCY", notice_rs.getInt(5));  
                studies.add(study);    
            }

            stmt.close();
            conn.close();
            out.println(studies); 
        }
        /*
           LOAD_SITE_MEMBERS
            Input : 
            Output : LOAD_SITE_MEMBERS(JSON)
        */
        if(type.equals("LOAD_SITE_MEMBERS")){

       
            String query = "SELECT * FROM INVESTIGATOR WHERE SITEID = "+SITEID + " and ACTIVE=1  order by INVID  ";
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
        


        else if(type.equals("LOAD_EXTRA_CONTENTS")){

            //Load Study Details
            String SID = request.getParameter("SID");

            //Load Extra Contents
            String load_study_detail_query = "SELECT SDTITLE, SDCONTENT FROM STUDY_DETAIL WHERE SDPUBLISHED = 1 and SID = " + SID;
            ResultSet detail_rs = stmt.executeQuery(load_study_detail_query);
            JSONArray study_details = new JSONArray();

            while(detail_rs.next()){
                JSONObject detail = new JSONObject();
                detail.put("TITLE", detail_rs.getString(1));
                detail.put("CONTENT", detail_rs.getString(2));
                study_details.add(detail);
            }

            stmt.close();
            conn.close();
            out.println(study_details); 
        }

        else if(type.equals("LOAD_STUDY_CONSENT_LIST")){

            //Load Study information
            String SID = request.getParameter("SID");
            String CSGRPID = request.getParameter("CSGRPID");
            //Load Consents

            int last_consentid=0;
            //가장 최근의 active 한 동의서 id
            String load_last_active_consent_query = "SELECT  IFNULL(CONSENTID,0) as CONSENTID FROM CONSENT WHERE SID = " + SID +" and CSGRPID="+CSGRPID+" and ISPUBLISH=1 order by CPUBLISHDTC DESC LIMIT 1";
            ResultSet last_consent_rs = stmt.executeQuery(load_last_active_consent_query);
           
          
            while(last_consent_rs.next()){
                last_consentid=last_consent_rs.getInt("CONSENTID");
            }

            String load_consent_list_query = "SELECT CFILE, CFILENAME, CVERSION, DATE_FORMAT(CPUBLISHDTC,'%Y-%m-%d')  as CPUBLISHDTC, CONSENTID, ISPUBLISH , IFNULL(CFILE_HASH, '') as CFILE_HASH FROM CONSENT WHERE SID = " + SID +" and CSGRPID="+CSGRPID+" order by CONSENTID DESC";
            ResultSet consent_rs = stmt.executeQuery(load_consent_list_query);
            JSONArray consents = new JSONArray();
            
            while(consent_rs.next()){
                JSONObject consent = new JSONObject();
                consent.put("CFILE", consent_rs.getString(1));
                consent.put("CFILENAME", consent_rs.getString(2));
                consent.put("CVERSION", consent_rs.getString(3));
                consent.put("CPUBLISHDTC", consent_rs.getString("CPUBLISHDTC"));
                consent.put("CONSENTID", consent_rs.getInt("CONSENTID"));
                consent.put("ISPUBLISH", consent_rs.getInt(6));
                consent.put("CFILE_HASH", consent_rs.getString("CFILE_HASH"));
                consent.put("contextpath",request.getContextPath());
               
                 consent.put("LAST_CONSENTID",last_consentid);
                consents.add(consent);
            }
            
            stmt.close();
            conn.close();
            out.println(consents);
        }

        else if(type.equals("LOAD_STUDY_CONSENT")){

            //Load Study information
            String CONSENTID = request.getParameter("CONSENTID");

            //Load Consents
            String load_consent_query = "SELECT CFILE, CFILENAME, CVERSION,DATE_FORMAT(CPUBLISHDTC,'%Y-%m-%d')  as CPUBLISHDTC , CONSENTID, ISPUBLISH, CONTACT_COPTION, INV_SIGN_COPTION  FROM CONSENT WHERE CONSENTID = " + CONSENTID;
            ResultSet consent_rs = stmt.executeQuery(load_consent_query);
            JSONArray consents = new JSONArray();
            
            while(consent_rs.next()){
                JSONObject consent = new JSONObject();
                consent.put("CFILE", consent_rs.getString(1));
                consent.put("CFILENAME", consent_rs.getString(2));
                consent.put("CVERSION", consent_rs.getString(3));
                consent.put("CPUBLISHDTC", consent_rs.getString("CPUBLISHDTC"));
                consent.put("CONSENTID", consent_rs.getInt(5));
                consent.put("ISPUBLISH", consent_rs.getInt(6));
                consent.put("CONTACT_COPTION", consent_rs.getInt(7));
                consent.put("INV_SIGN_COPTION", consent_rs.getInt(8));
                consents.add(consent);
            }

            stmt.close();
            conn.close();
            out.println(consents);
        }

        else if(type.equals("LOAD_STUDY_CONSENT_SIGNFORM")){
            //Load Consent information
            String CONSENTID = request.getParameter("CONSENTID");
            
            //Load Sign Form
            String load_signform_query = "SELECT CDIDNUM, CDTITLE, CDCONTENT FROM CONSENT_DETAIL WHERE CONSENTID = " + CONSENTID;
            ResultSet signform_detail_rs = stmt.executeQuery(load_signform_query);
            JSONArray signform_details = new JSONArray();

            while(signform_detail_rs.next()){
                JSONObject detail = new JSONObject();
                detail.put("CONSENTID", CONSENTID);
                detail.put("CDIDNUM", signform_detail_rs.getInt(1));
                detail.put("TITLE", signform_detail_rs.getString(2));
                detail.put("CONTENT", signform_detail_rs.getString(3));
                signform_details.add(detail);
            }

            stmt.close();
            conn.close();
            out.println(signform_details);
        }

        /*
            Delete extra contents
            Input : SID
            Output : Null
        */
        else if(type.equals("DELETE_EXTRA_CONTENTS")){

            //Load Study information
            String SID = request.getParameter("SID");

            //Delete Extra Contents From Database - step1
            List<Integer> SDIDarr = new ArrayList();
            String selectSDIDquery = "select SDID from study_detail where SID="+SID;
            ResultSet rs = stmt.executeQuery(selectSDIDquery);
            while(rs.next()) SDIDarr.add(rs.getInt(1));

            //Delete Extra Contents From Database - step2
            String delete_extra_query = "DELETE FROM STUDY_DETAIL WHERE SID = "+SID;
            stmt.executeUpdate(delete_extra_query);

            //STUDY_DETAIL_LOG 저장 - DELETE
            for(int idx=0; idx<SDIDarr.size(); idx++){
                String studyDetailLogInsertQuery = "INSERT INTO STUDY_DETAIL_LOG(SDID, SDPUBLISHED, WHO, WHO_ID, HOW, LOGDTC ) values("+SDIDarr.get(idx)+",null,'SITE',"+INVID+",'DELETE',NOW())";
                stmt.executeUpdate(studyDetailLogInsertQuery);
            }

            stmt.close();
            conn.close();
        }

        /*
            Delete Sign form
            Input : CONSENTID
            Output : Null
        */
        else if(type.equals("DELETE_SIGN_FORM")){

            //Load Study information
            String CONSENTID = request.getParameter("CONSENTID");

            //Delete Extra Contents From Database - step1
            String selectCDIDquery = "select CDID from CONSENT_DETAIL where CONSENTID="+CONSENTID;
            ResultSet rs = stmt.executeQuery(selectCDIDquery);
            List<Integer> CDIDarr = new ArrayList(); // 지워질 CDID 저장 Array
            while(rs.next()) CDIDarr.add(rs.getInt(1));

            //Delete Extra Contents From Database - step2
            String delete_extra_query = "DELETE FROM CONSENT_DETAIL WHERE CONSENTID = "+CONSENTID;
            stmt.executeUpdate(delete_extra_query);

            // CONSENT_DETAIL_LOG 저장 - DELETE
            for(int idx=0; idx<CDIDarr.size(); idx++){
                String logquery="INSERT INTO CONSENT_DETAIL_LOG(CDID, PAGENUM, MINDURATION, WHO, WHO_ID, HOW, LOGDTC ) values("+CDIDarr.get(idx)+","+null+","+null+",'SITE',"+INVID+",'DELETE',NOW())";
                stmt.executeUpdate(logquery);
            }

            stmt.close();
            conn.close();
        }

        /*
            Delete AD file : SFILE, SFILENAME
            Input : SID
            Output : Null
        */
        else if(type.equals("DELETE_SFILE")){

            //Load Study information
            String SID = request.getParameter("SID");

            //Delete SFILE info form From Database
            String delete_sign_form_query = "UPDATE STUDY SET SFILE = null, SFILENAME=null WHERE SID = "+SID;
            stmt.executeUpdate(delete_sign_form_query);

            // STUDY_LOG 저장 - UPDATE
            String studyLogPrevQuery = selectPreviousInformation(stmt, "STUDY_LOG", "STUDY", tableSchemaName);
            String studyLogInsertQuery = studyLogPrevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from STUDY where SID="+SID;
            stmt.executeUpdate(studyLogInsertQuery);

            stmt.close();
            conn.close();
        }
        /*
            Delete CONSENT file : CFILE, CFILENAME
            Input : CONSENTID
            Output : Null
        */
        else if(type.equals("DELETE_CFILE")){

            //Load Study information
            String CONSENTID = request.getParameter("CONSENTID");

            //Delete SFILE info form From Database
            String delete_sign_form_query = "UPDATE CONSENT SET CFILE = '', CFILENAME=''  WHERE CONSENTID = "+CONSENTID;
            log("[METORY log]"+"\t||\t[SITEID]="+SITEID+"\t||\t[INVID]="+INVID+"\t||\t[type]="+type+"\t||\t[QUERY]="+delete_sign_form_query.replace("'", "\'"));  
            stmt.executeUpdate(delete_sign_form_query);
          

            stmt.close();
            conn.close();
        }
        /*
            Delete Consent
            Input : CONSENTID
            Output : Null
        */
        else if(type.equals("DELETE_CONSENT")){

            //Load Study information
            String CONSENTID = request.getParameter("CONSENTID");

            //Delete Sign form From Database - step1
            String selectCDIDquery = "select CDID from CONSENT_DETAIL where CONSENTID="+CONSENTID;
            ResultSet rs = stmt.executeQuery(selectCDIDquery);
            List<Integer> CDIDarr = new ArrayList(); // 지워질 CDID 저장 Array
            while(rs.next()) CDIDarr.add(rs.getInt(1));

            //Delete Sign form From Database - step2
            String delete_sign_form_query = "DELETE FROM CONSENT_DETAIL WHERE CONSENTID = "+CONSENTID;
            stmt.executeUpdate(delete_sign_form_query);

            // CONSENT_DETAIL_LOG 저장 - DELETE
            for(int idx=0; idx<CDIDarr.size(); idx++){
                String consentDetailLogInsertQuery="INSERT INTO CONSENT_DETAIL_LOG(CDID, PAGENUM, MINDURATION, WHO, WHO_ID, HOW, LOGDTC ) values("+CDIDarr.get(idx)+",null, null,'SITE',"+INVID+",'DELETE',NOW())";
                stmt.executeUpdate(consentDetailLogInsertQuery);     
            }

            //Delete Consent From Database
            String delete_consent_query = "DELETE FROM CONSENT WHERE CONSENTID = "+CONSENTID;
            stmt.executeUpdate(delete_consent_query);

            // CONSENT_LOG 저장 - DELETE
            String consentLogInsertQuery="INSERT INTO CONSENT_LOG(CONSENTID, ISPUBLISH, CONTACT_COPTION, INV_SIGN_COPTION, RECENT_PUBLISHED, WHO, WHO_ID, HOW, LOGDTC) values("+CONSENTID+",null,null,null,null,'SITE',"+INVID+",'DELETE',NOW())";
            stmt.executeUpdate(consentLogInsertQuery);

            stmt.close();
            conn.close();
        }
        /*
            Delete Sign form
            Input : SID, CONSENTID
            Output : Null
        */
        else if(type.equals("PUBLISH_CONSENT")){
            //create a new consent version

            //Load Study information
            String SID = request.getParameter("SID");
            String CONSENTID = request.getParameter("CONSENTID");
          

            //Delete Extra Contents From Database
                
            String query_select_ongoing_subject = "select SAID from  study_applicant where SID = "+SID+" and CLOSESTAGE not in (9, 10, 13, 14)";
            ResultSet rs_ongoing = stmt.executeQuery(query_select_ongoing_subject);
           // Statement stmt1 =null;
            Statement stmt2 =null;
           // stmt1 = conn.createStatement();
            try{
                stmt2 = conn.createStatement();

                while(rs_ongoing.next()){
                // String query_select_subject_said = "select SAID from study_applicant where SID = "+SID+" and APPLID = "+rs_ongoing.getInt(2);
                // ResultSet rs_said = stmt1.executeQuery(query_select_subject_said);
                // while(rs_said.next()){
                    String query_said_insert = "insert into consent_subject(SAID, CONSENTID, SID, SITEID, CSSTAGE) values("+rs_ongoing.getInt(1)+", "+CONSENTID+", "+SID+", "+SITEID+", 15);";
                    log("[METORY log]"+"\t||\t[SITEID]="+SITEID+"\t||\t[INVID]="+INVID+"\t||\t[type]="+type+"\t||\t[QUERY]="+query_said_insert.replace("'", "\'"));     
                    stmt2.executeUpdate(query_said_insert);
                //  }
                }

                stmt.close();
            // stmt1.close();
                stmt2.close();
                conn.close();
            }catch(Exception e){
                e.printStackTrace();
            }
            finally{
                if(stmt2!=null)       stmt2.close();
            }
            
        }

        else if(type.equals("prtno_load")){
            String SID = request.getParameter("SID");
            String query = "SELECT PRTNO FROM STUDY WHERE SID = "+SID;
            ResultSet rs = stmt.executeQuery(query);

            String PRTNO = "";

            while(rs.next()){
                PRTNO = rs.getString(1);
            }

            stmt.close();
            conn.close();
            out.println(PRTNO);
        }

        else if(type.equals("publish")){
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

            String publish_query = "UPDATE STUDY SET SSTAT = 2, SPUBLISHDTC='"+today+"' WHERE SID = "+SID;
            log("[METORY log]"+"\t||\t[SITEID]="+SITEID+"\t||\t[INVID]="+INVID+"\t||\t[type]="+type+"\t||\t[QUERY]="+publish_query.replace("'", "\'"));
            stmt.executeUpdate(publish_query);

            stmt.close();
            conn.close();
            out.println("publish_query=========================="+publish_query );
        }
        else if(type.equals("complete")){
            String SID = request.getParameter("SID");
            String publish_query = "UPDATE STUDY SET SSTAT = 3 WHERE SID = "+SID;
            log("[METORY log]"+"\t||\t[SITEID]="+SITEID+"\t||\t[INVID]="+INVID+"\t||\t[type]="+type+"\t||\t[QUERY]="+publish_query.replace("'", "\'"));
            stmt.executeUpdate(publish_query);

            stmt.close();
            conn.close();
            out.println("complete=========================="+publish_query );
        }
        else if(type.equals("finish")){
            String SID = request.getParameter("SID");
            String publish_query = "UPDATE STUDY SET SSTAT = 4 WHERE SID = "+SID;
            log("[METORY log]"+"\t||\t[SITEID]="+SITEID+"\t||\t[INVID]="+INVID+"\t||\t[type]="+type+"\t||\t[QUERY]="+publish_query.replace("'", "\'"));
            stmt.executeUpdate(publish_query);

            stmt.close();
            conn.close(); 
            out.println("finish=========================="+publish_query );
        }

        else if(type.equals("modify")){
            
        
            String SID = request.getParameter("SID");
            out.print("-------------SID"+SID);
            String SPONSOR = URLDecoder.decode(request.getParameter("SPONSOR"), "UTF-8");

            String PRTNO = URLDecoder.decode(request.getParameter("PRTNO"), "UTF-8");
            String STITLE = URLDecoder.decode(request.getParameter("STITLE"), "UTF-8");
            String SAPPLICANT = URLDecoder.decode(request.getParameter("SAPPLICANT"), "UTF-8");
            String SSEX = request.getParameter("SSEX");
            String SNUM = request.getParameter("SNUM");
            String STARGET = URLDecoder.decode(request.getParameter("STARGET"), "UTF-8");
            String SDATE = URLDecoder.decode(request.getParameter("SDATE"), "UTF-8");
            String SFILE = URLDecoder.decode(request.getParameter("SFILE"), "UTF-8");
            String SFILENAME = URLDecoder.decode(request.getParameter("SFILENAME"), "UTF-8");
            String SSTAT = request.getParameter("SSTAT");
            String SPUBLISHED = request.getParameter("SPUBLISHED");
            String ORDER = request.getParameter("ORDER");
            // String CFILE = URLDecoder.decode(request.getParameter("CFILE"), "UTF-8");
            // String CVERSION = URLDecoder.decode(request.getParameter("CVERSION"), "UTF-8");

            DecimalFormat df = new DecimalFormat("00");
            Calendar calendar = Calendar.getInstance();
            String year = Integer.toString(calendar.get(Calendar.YEAR)); 
            String month = df.format(calendar.get(Calendar.MONTH) + 1); 
            String day = df.format(calendar.get(Calendar.DATE)); 
            String hour = df.format(calendar.get(Calendar.HOUR_OF_DAY));
            String minute = df.format(calendar.get(Calendar.MINUTE));
            String second = df.format(calendar.get(Calendar.SECOND));
            String today = year+"-"+month+"-"+day+" "+hour+":"+minute+":"+second;

            String exist_query = "select EXISTS (select * from SPONSOR where SPONSORNAME = '" + SPONSOR +"') as success;";
            ResultSet exist_rs = stmt.executeQuery(exist_query);
            int exist = 0;
            while(exist_rs.next()){
                exist = exist_rs.getInt(1);
            }


            if (exist==0){//add a new sponsor

                String insert_query = "INSERT INTO SPONSOR(SPONSORNAME) values( '"+SPONSOR+"' );";
                log("[METORY log]"+"\t||\t[SITEID]="+SITEID+"\t||\t[INVID]="+INVID+"\t||\t[type]="+type+"\t||\t[QUERY]="+insert_query.replace("'", "\'"));
                stmt.executeUpdate(insert_query);   
            }
            

            String search_query = "SELECT SPONSORID FROM SPONSOR WHERE SPONSORNAME = '"+SPONSOR+"';";
            ResultSet search_rs = stmt.executeQuery(search_query);
            int SPONSORID = 0;
            while(search_rs.next()){
                SPONSORID = search_rs.getInt(1);
            }
            String query = "";

            if(SFILE.equals("")){
                query = "UPDATE STUDY SET SPONSORID= "+SPONSORID+", PRTNO = '"+PRTNO+"', TITLE = '"+STITLE+"', SAPPL ='"+SAPPLICANT+"', SSEX ="+SSEX+", SNUM = "+SNUM+", STARGET = '"+STARGET+"', SDATE = '"+SDATE+"', SSTAT = "+SSTAT+", SPUBLISHED = "+SPUBLISHED+", ORDERS = "+ORDER+" WHERE SID="+SID;
            }
            else{
                query = "UPDATE STUDY SET SPONSORID="+SPONSORID+", PRTNO = '"+PRTNO+"', TITLE = '"+STITLE+"', SAPPL ='"+SAPPLICANT+"', SSEX ="+SSEX+", SNUM = "+SNUM+", STARGET = '"+STARGET+"', SDATE = '"+SDATE+"', SFILE ='"+SFILE+"', SFILENAME='"+SFILENAME+"', SSTAT = "+SSTAT+", SPUBLISHED = "+SPUBLISHED+", ORDERS = "+ORDER+" WHERE SID="+SID;
            }
            log("[METORY log]"+"\t||\t[SITEID]="+SITEID+"\t||\t[INVID]="+INVID+"\t||\t[type]="+type+"\t||\t[QUERY]="+query.replace("'", "\'"));
            stmt.executeUpdate(query);
            out.println("modify1==="+query);
            switch(SPUBLISHED){
                case "2":
                    query = "UPDATE STUDY SET SPUBLISHDTC = '"+today+"' WHERE SID="+SID;
                    log("[METORY log]"+"\t||\t[SITEID]="+SITEID+"\t||\t[INVID]="+INVID+"\t||\t[type]="+type+"\t||\t[QUERY]="+query.replace("'", "\'"));
                    stmt.executeUpdate(query);
                break;
            }
          

            stmt.close();
            conn.close();
            out.println("modify2=="+query);
        }
        /*
            load sponsor list
            Input :
            Output : sponsor_name list
        */
        else if(type.equals("load_sponsors")){
       
            String query = "SELECT SPONSORID, SPONSORNAME FROM SPONSOR ORDER BY SPONSORNAME ASC";
            ResultSet rs = stmt.executeQuery(query);

            JSONArray sponsors = new JSONArray();

            while(rs.next()){
                JSONObject sponsor = new JSONObject();
                sponsor.put("SPONSORID", rs.getInt(1));
                sponsor.put("SPONSORNAME", rs.getString(2));
                
                sponsors.add(sponsor);
            }

            stmt.close();
            conn.close();
            out.println(sponsors);
        }
        /*
            LOAD_SITE_DOCTOR_LIST : get list who DOCTOR==1 @INVESTIGATOR table
            Input :
            Output : INVNAME and INVID  JSONARRAY 
        */
        else if(type.equals("LOAD_SITE_DOCTOR_LIST")){

            String query = "SELECT INVID, INVNAME, INVMAIL FROM INVESTIGATOR  WHERE SITEID="+SITEID+" and DOCTOR=1  and ACTIVE=1 ORDER BY INVNAME ASC";
            ResultSet rs = stmt.executeQuery(query);

            JSONArray pis = new JSONArray();

            while(rs.next()){
                JSONObject pi = new JSONObject();
                pi.put("INVID", rs.getInt(1));
                pi.put("INVNAME", rs.getString(2));
                pi.put("INVMAIL", rs.getString("INVMAIL"));
                
                pis.add(pi);
            }

            stmt.close();
            conn.close();
            out.println(pis);
        }
        else if(type.equals("SAVE_QUESTION")){
            String criterias = request.getParameter("criterias");

            JSONParser parser = new JSONParser();
            JSONArray criteriaArray = (JSONArray)parser.parse(criterias);

            String maxItemGroupIdFindQuery = "SELECT MAX(ANSWER_ITEM_GROUP_ID) from answer_item";
            String questionType = "";

            ResultSet rs = stmt.executeQuery(maxItemGroupIdFindQuery);
            JSONArray pis = new JSONArray();

            // 변수 준비
            int answerItemGroupId = 0;

            //criteriaArray[idx].get("keyNAme") 이렇게 뽑기 가능?? -> 추후 삭제 라인

            // max id 체크
            while(rs.next()){
                answerItemGroupId = rs.getInt(1);
            }

            
            for(int idxNum=0; idxNum<criteriaArray.size(); idxNum++){
                JSONObject criteria = (JSONObject)criteriaArray.get(idxNum);
                String title = criteria.get("title").toString();
                //JSONObject answer = (JSONObject)criteria.get()
                //String answerTitleInsertQuery = "INSERT INTO question(QUESTION_CONTENT, ANSWER_TYPE_CONCEPT_ID) values('"+title+"','1001');";
                //JSONArray answer = (JSONArray)parser.parse(criteriaArray[idxNum].get("answer"));
                
                
                // 문제 제목 추가 쿼리실행 (현재 한글 깨짐)
                
                //stmt.executeUpdate(answerTitleInsertQuery);
            }


            
            //rs = stmt.executeQuery(exquery);

            //while(rs.next()){
                //JSONObject pi = new JSONObject();
                //pi.put("INVID", rs.getInt(1));
                //pi.put("INVNAME", rs.getString(2));
                //pi.put("INVMAIL", rs.getString(4));
                //pis.add(pi);
            //}
            
            stmt.close();
            conn.close();
            out.println(pis);
        }
        else if(type.equals("MODIFY_STUDY_INVS")){          
    

            //Setting JSON Parser
            JSONParser parser = new JSONParser();
            

            String SID = request.getParameter("SID");
            String rows = request.getParameter("contents");

            //Parse Study invs information
            rows = URLDecoder.decode(rows, "UTF-8");
            JSONArray invs = (JSONArray)parser.parse(rows);

            //Delete Study invs From Database - step1
            List<Integer> SIIDarr = new ArrayList();
            String selectSIIDquery = "select SIID from STUDY_INV where SID="+SID;
            ResultSet rs = stmt.executeQuery(selectSIIDquery);
            while(rs.next()) SIIDarr.add(rs.getInt(1));

            //Delete Study invs From Database - step2
            String delete_extra_query = "DELETE FROM STUDY_INV WHERE SID = "+SID ;
            stmt.executeUpdate(delete_extra_query);

            //STUDY_INV_LOG 저장 - DELETE
            String logquery = "";
            for(int idx=0; idx<SIIDarr.size(); idx++){
                logquery = "INSERT INTO STUDY_INV_LOG(SIID, WHO, WHO_ID, HOW, LOGDTC) values("+SIIDarr.get(idx)+",'SITE',"+INVID+",'DELETE', NOW())";
                stmt.executeUpdate(logquery);
            }

            //Insert Study invs
            for(int i = 0; i < invs.size(); i++){
                JSONObject aInv = (JSONObject)invs.get(i);
                String aINVID = String.valueOf(aInv.get("INVID"));
                String SIROLECODE = String.valueOf(aInv.get("SIROLECODE"));
                String SIROLETITLE = String.valueOf(aInv.get("SIROLETITLE"));              
                String SIMODIFYROLE = String.valueOf(aInv.get("MODIFY"));
                String SIRESERVEROLE = String.valueOf(aInv.get("RESERVE"));
                String SIIDENTITYROLE = String.valueOf(aInv.get("IDENTITY"));
                String SICONSENTROLE = String.valueOf(aInv.get("CONSENT"));
                String SISIGNROLE = String.valueOf(aInv.get("SIGN"));
            
                String insert_extra_query = "INSERT INTO STUDY_INV(SID, INVID, SIROLECODE, SIROLETITLE,SIMODIFYROLE,SIRESERVEROLE, SIIDENTITYROLE,SICONSENTROLE,  SISIGNROLE) values("+SID+", "+aINVID+", "+ SIROLECODE+", '"+SIROLETITLE+"',"  + SIMODIFYROLE + ","+SIRESERVEROLE+ ","+ SIIDENTITYROLE+","+ SICONSENTROLE+","+SISIGNROLE+ ")";
                stmt.executeUpdate(insert_extra_query);
                int insertedSIID = getLastInsertID(stmt);

                // STUDY_INV_LOG 저장 - CREATE
                String studyINVPrevQuery = selectPreviousInformation(stmt, "STUDY_INV_LOG", "STUDY_INV", tableSchemaName);
                String studyINVLogInsertQuery = studyINVPrevQuery+",'SITE', "+INVID+",'CREATE',NOW() from STUDY_INV where SIID="+insertedSIID;
                stmt.executeUpdate(studyINVLogInsertQuery);

                // out.println(insert_extra_query);
            }

            // 문자 수신 핸드폰 번호 study에 저장하기
            String SMS_RECEIVER = request.getParameter("SMS_RECEIVER");

           // if(SMS_RECEIVER !=null  && !SMS_RECEIVER.isEmpty() ){
                  String update_query = "UPDATE STUDY SET SMS_RECEIVER =  '"+SMS_RECEIVER+"' WHERE SID= "+SID;
                  stmt.executeUpdate(update_query);
                  // STUDY_LOG 저장 - UPDATE
                  String studyLogPrevQuery = selectPreviousInformation(stmt, "STUDY_LOG", "STUDY", tableSchemaName);
                  String studyLogInsertQuery = studyLogPrevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from STUDY where SID="+SID;
                  stmt.executeUpdate(studyLogInsertQuery);

           // }
            stmt.close();
            conn.close();
            out.println("success");
        }
        /*
        else if(type.equals("extra_modify")){

            JSONParser jsonParser = new JSONParser();
            String SID = request.getParameter("SID");
            String extras = request.getParameter("contents");
            extras = URLDecoder.decode(extras, "UTF-8");

            String delete_query = "DELETE FROM STUDY_DETAIL WHERE SID = "+SID;
            stmt.executeUpdate(delete_query);

            if(!extras.equals("null")){
                JSONParser parser = new JSONParser();
                JSONArray contents = (JSONArray)parser.parse(extras);
                int INVID = (int)session.getAttribute("INVID");

                for(int i = 0; i < contents.size(); i++){
                    JSONObject content = (JSONObject)contents.get(i);
                    String SDTITLE = String.valueOf(content.get("title"));
                    String SDCONTENT = String.valueOf(content.get("content"));
                    
                    String query = "INSERT INTO STUDY_DETAIL(SID, INVID, SDTITLE, SDCONTENT) values("+SID+", "+INVID+", '"+SDTITLE+"', '"+SDCONTENT+"')";
                    stmt.executeUpdate(query);
                }
            }
            stmt.close();
            conn.close();
        }*/
        /*
        else if(type.equals("load_analysis")){
            String SID = request.getParameter("SID");

            String applydate_query = "SELECT APPLDTC, count(*) FROM STUDY_APPLICANT WHERE SID = "+SID+" GROUP BY APPLDTC ORDER BY APPLDTC";
            String applygender_query = "SELECT A.APPLSEX, count(*) FROM STUDY_APPLICANT SA, APPLICANT A WHERE A.APPLID = SA.APPLID and SA.SID = "+SID+" GROUP BY A.APPLSEX";
            String applystatus_query = "SELECT SA.APPLST, count(*) FROM STUDY_APPLICANT SA, APPLICANT A WHERE A.APPLID = SA.APPLID and SA.SID = "+SID+" GROUP BY SA.APPLST";
            String visitdate_query = "SELECT SUBSTRING_INDEX(VISITDTC, ' ', 1), count(*) FROM STUDY_APPLICANT WHERE SID = "+SID+" GROUP BY SUBSTRING_INDEX(VISITDTC, ' ', 1) ORDER BY VISITDTC";

            JSONArray analysisdata = new JSONArray();

            ResultSet rs = stmt.executeQuery(applydate_query);
            JSONArray applydate = new JSONArray();
            while(rs.next()){
                JSONObject apply = new JSONObject();
                apply.put("APPLDTC", rs.getString(1));
                apply.put("COUNT", rs.getInt(2));
                applydate.add(apply);
            }
            analysisdata.add(applydate);

            ResultSet rs1 = stmt.executeQuery(applygender_query);
            JSONArray applygender = new JSONArray();
            while(rs1.next()){
                JSONObject apply = new JSONObject();
                apply.put("APPLSEX", rs1.getString(1));
                apply.put("COUNT", rs1.getInt(2));
                applygender.add(apply);
            }
            analysisdata.add(applygender);

            ResultSet rs2 = stmt.executeQuery(applystatus_query);
            JSONArray applystatus = new JSONArray();
            while(rs2.next()){
                JSONObject apply = new JSONObject();
                apply.put("APPLST", rs2.getString(1));
                apply.put("COUNT", rs2.getInt(2));
                applystatus.add(apply);
            }
            analysisdata.add(applystatus);

            ResultSet rs3 = stmt.executeQuery(visitdate_query);
            JSONArray visitdate = new JSONArray();
            while(rs3.next()){
                JSONObject apply = new JSONObject();
                apply.put("VISITDTC", rs3.getString(1));
                apply.put("COUNT", rs3.getInt(2));
                visitdate.add(apply);
            }
            analysisdata.add(visitdate);

            stmt.close();
            conn.close();
            out.println(analysisdata);

        }*/

        else if(type.equals("title_load")){ 
            String SID = request.getParameter("SID");
            String query = "SELECT TITLE, PRTNO FROM STUDY WHERE SID = "+SID;
            ResultSet rs = stmt.executeQuery(query);

            JSONObject study = new JSONObject();

            while(rs.next()){
                study.put("TITLE",rs.getString(1));
                study.put("PRTNO",rs.getString(2));  
                study.put("INVNAME", session.getAttribute("INVNAME"));          
            }


            stmt.close();
            conn.close();
            out.println(study);
        }  


        /*
            목적: 연구자가 블록체인 연결 요청
            행동: update BCSTAGE=1 @ STUDY
            Input : SID
            Output : "success"
        */
        else if(type.equals("STARTBC")){
  
            String SID = request.getParameter("SID");
            
            String modify_study_query = "UPDATE STUDY SET BCSTAGE = 1 WHERE SID = "+SID + " and SITEID="+SITEID;
            stmt.executeUpdate(modify_study_query);

            // STUDY_LOG 저장 - UPDATE
            String studyLogPrevQuery = selectPreviousInformation(stmt, "STUDY_LOG", "STUDY", tableSchemaName);
            String studyLogInsertQuery = studyLogPrevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from STUDY where SID="+SID;
            stmt.executeUpdate(studyLogInsertQuery); 

            stmt.close();
            conn.close();
            out.println("success");
        }


           /*
            목적: 사용자가 하는 특정 행동에 대한 권한 확인
            행동: 
            Input : SID, CHECKROLE, CREATOR_PRIORITY
            Output : JSON.result
        */
        else if(type.equals("CHECK_ONE_ROLE")){
       
            String SID = request.getParameter("SID");
            String CHECKROLE = request.getParameter("CHECKROLE");
            String CREATOR_PRIORITY = request.getParameter("CREATOR_PRIORITY");

            JSONObject study = new JSONObject();
      
            //CREATOR_PRIORITY==TRUE 인 경우 연구생성자면 JSON.result=1을 리턴한다.
            int result=0;
            if(CREATOR_PRIORITY.equals("TRUE")){
                String study_query = "SELECT COUNT(INVID) as COUNT, INVID from STUDY WHERE SID = "+SID + " and INVID="+INVID;
                ResultSet rs = stmt.executeQuery(study_query);   

                while(rs.next()){
                    if(rs.getInt("COUNT")>0){
                        result=1;
                   
                    }            
                }

            }

            if(result==0) {         
                String modify_study_query = "SELECT COUNT(INVID) as COUNT, INVID  from STUDY_INV WHERE SID = "+SID + " and INVID="+INVID + " and "+CHECKROLE+"=1";
                ResultSet rs2 = stmt.executeQuery(modify_study_query);

            
                while(rs2.next()){
                    if(rs2.getInt("COUNT")>0){
                        result=1;
                     
                    }
            
                }
                
            } 
            study.put("result",result);
            stmt.close();
            conn.close();
            out.println(study);
        }
        
           /*
            목적: 사용자가 하는 해당 연구의 자원자 정보를 볼 수 있는지에 대한 권한 확인
            행동: 
            Input : SID
            Output : JSON.result
        */
        else if(type.equals("CHECK_VIEW_APPLICANTS")){
          
            String SID = request.getParameter("SID");
    
            JSONObject study = new JSONObject();
      
            //모든 checkrole 에 사용할 수 있도록 creator_priority 가 있는 경우 권한 체크하고 바로 리턴한다.
            int result=0;
            

            
                String modify_study_query = "SELECT COUNT(INVID) as COUNT, INVID, SISIGNROLE, SICONSENTROLE , SIIDENTITYROLE , SIRESERVEROLE from STUDY_INV WHERE SID = "+SID + " and INVID="+INVID;
                ResultSet rs2 = stmt.executeQuery(modify_study_query);

            
                while(rs2.next()){
                    if(rs2.getInt("COUNT")>0){
                        if(rs2.getInt("SISIGNROLE")==1 || rs2.getInt("SICONSENTROLE")==1 || rs2.getInt("SIIDENTITYROLE")==1 || rs2.getInt("SIRESERVEROLE")==1)
                            result=1;
                      
                    }
            
                }
                
           
            study.put("result", result);

            stmt.close();
            conn.close();
            out.println(study);
        }

     /*
           UPDATE_APPOINT_FIX
            Input : INVID, SID, EXTRA_CONTENTS
            Output : Null
        */
        else if(type.equals("UPDATE_APPOINT_FIX")){

            //Setting JSON Parser
            JSONParser parser = new JSONParser();
            

            //Load Study information
            String SID = request.getParameter("SID");
            String extras = request.getParameter("contents");

            //Parse Study extra Contents
            extras = URLDecoder.decode(extras, "UTF-8");
            JSONArray contents = (JSONArray)parser.parse(extras);

            //Delete Extra Contents From Database - step1
            List<Integer> AFIDarr = new ArrayList();
            String afidSelectQuery = "select AFID from APPOINT_FIX where SID="+SID;
            ResultSet rs = stmt.executeQuery(afidSelectQuery);
            while(rs.next()){
                AFIDarr.add(rs.getInt(1));
            }
            
            //Delete Extra Contents From Database - step2
            String delete_extra_query = "DELETE FROM APPOINT_FIX WHERE SID = "+SID;
            stmt.executeUpdate(delete_extra_query);

            // APPOINT_FIX_LOG 저장 - DELETE
            for(int idx=0; idx<AFIDarr.size(); idx++){
                String appointFixLogQuery = "INSERT INTO APPOINT_FIX_LOG(AFID, WHO, WHO_ID, HOW, LOGDTC) values("+AFIDarr.get(idx)+", 'SITE',"+INVID+",'DELETE',NOW())";
                stmt.executeUpdate(appointFixLogQuery); 
            }

            //Insert Extra Contents
            for(int i = 0; i < contents.size(); i++){
                JSONObject content = (JSONObject)contents.get(i);
                String AFDATE =String.valueOf(content.get("date"));               
                String AFTIME = String.valueOf(content.get("time"));
                String MAX = String.valueOf(content.get("max"));
                String insert_extra_query="";
                if(AFDATE.equals("")){
                    insert_extra_query = "INSERT INTO APPOINT_FIX(SID, INVID, AFTIME, MAX) values("+SID+", "+INVID+", '"+AFTIME+"',"+MAX+")";
                }
                else if(AFTIME.equals("")){
                    insert_extra_query = "INSERT INTO APPOINT_FIX(SID, INVID, AFDATE,  MAX) values("+SID+", "+INVID+", '"+AFDATE+"', "+MAX+")";
                }
                else {
                    insert_extra_query = "INSERT INTO APPOINT_FIX(SID, INVID, AFDATE, AFTIME, MAX) values("+SID+", "+INVID+", '"+AFDATE+"', '"+AFTIME+"',"+MAX+")";
                }
                stmt.executeUpdate(insert_extra_query);
                int insertedAFID = getLastInsertID(stmt);

                // APPOINT_FIX_LOG 저장 - CREATE
                String appointFixLogPrevQuery = selectPreviousInformation(stmt, "APPOINT_FIX_LOG", "APPOINT_FIX", tableSchemaName);
                String appointFixLogInsertQuery = appointFixLogPrevQuery+",'SITE', "+INVID+",'CREATE',NOW() from APPOINT_FIX where AFID="+insertedAFID;
                stmt.executeUpdate(appointFixLogInsertQuery);

            }

            String USE_APPOINTMENT = request.getParameter("USE_APPOINTMENT");

            String modify_study_query = "UPDATE STUDY SET USE_APPOINTMENT = "+USE_APPOINTMENT+" WHERE SID="+SID;
            stmt.executeUpdate(modify_study_query);

            // STUDY_LOG 저장 - UPDATE
            String studyLogPrevQuery = selectPreviousInformation(stmt, "STUDY_LOG", "STUDY", tableSchemaName);
            String studyLogInsertQuery = studyLogPrevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from STUDY where SID="+SID;
            stmt.executeUpdate(studyLogInsertQuery);

            stmt.close();
            conn.close();
        }

          /*
            Delete DELETE_APPOINT_FIX
            Input : SID
            Output : Null
        */
        else if(type.equals("DELETE_APPOINT_FIX")){

            //Load Study information
            String SID = request.getParameter("SID");

            //Delete Extra Contents From Database - step1
            String afid_query = "SELECT AFID from APPOINT_FIX WHERE SID = "+SID ;
            ResultSet rs = stmt.executeQuery(afid_query);
            List<Integer> AFIDarr = new ArrayList<Integer>();
            while(rs.next()){
                AFIDarr.add(rs.getInt(1));                      
            }

            //Delete Extra Contents From Database - step2
            String delete_extra_query = "DELETE FROM APPOINT_FIX WHERE SID = "+SID;
            stmt.executeUpdate(delete_extra_query);

            // APPOINT_FIX_LOG 저장 - DELETE
            for(int i=0; i<AFIDarr.size();i++){
                String appointFixLogQuery="INSERT INTO APPOINT_FIX_LOG(AFID, WHO, WHO_ID, HOW, LOGDTC ) values("+AFIDarr.get(i)+",'SITE',"+INVID+",'DELETE',NOW())";
                stmt.executeUpdate(appointFixLogQuery);
            }

            String USE_APPOINTMENT = request.getParameter("USE_APPOINTMENT");

            String modify_study_query = "UPDATE STUDY SET USE_APPOINTMENT="+USE_APPOINTMENT+" WHERE SID="+SID;
            stmt.executeUpdate(modify_study_query);

            // STUDY_LOG 저장 - UPDATE
            String studyLogPrevQuery = selectPreviousInformation(stmt, "STUDY_LOG", "STUDY", tableSchemaName);
            String studyLogInsertQuery = studyLogPrevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from STUDY where SID="+SID;
            stmt.executeUpdate(studyLogInsertQuery);

            stmt.close();
            conn.close();
        }
        else if(type.equals("UPDATE_APPOINT_USAGE")){
             //Load Study Details
            String SID = request.getParameter("SID");
            String USE_APPOINTMENT = request.getParameter("USE_APPOINTMENT");

            String modify_study_query = "UPDATE STUDY SET USE_APPOINTMENT = "+USE_APPOINTMENT+"  WHERE SID="+SID;
            
            stmt.executeUpdate(modify_study_query);

            // STUDY_LOG 저장 - UPDATE
            String studyLogPrevQuery = selectPreviousInformation(stmt, "STUDY_LOG", "STUDY", tableSchemaName);
            String studyLogInsertQuery = studyLogPrevQuery+",'SITE', "+INVID+",'UPDATE',NOW() from STUDY where SID="+SID;
            stmt.executeUpdate(studyLogInsertQuery);

            stmt.close();
            conn.close();
            out.println("SUCCESS"); 
      
        }
          else if(type.equals("LOAD_APPOINT_USAGE")){
             //Load Study Details
            String SID = request.getParameter("SID");
             String USE_APPOINTMENT = request.getParameter("USE_APPOINTMENT");

             String study_query = "SELECT USE_APPOINTMENT from STUDY where SID= "+SID;
            
       ResultSet rs = stmt.executeQuery(study_query);
     

            while(rs.next()){              
             
 out.println(rs.getInt(1)); 
            }

            stmt.close();
            conn.close();
           
        }
          else if(type.equals("GET_USE_APPOINTMENT")){

            //Load Study Details
            String SID = request.getParameter("SID");

            //Load Extra Contents
           String load_study_detail_query= "SELECT USE_APPOINTMENT FROM STUDY WHERE  SID=" + SID;
            ResultSet detail_rs = stmt.executeQuery(load_study_detail_query);
            JSONArray study_details = new JSONArray();

            while(detail_rs.next()){
                JSONObject detail = new JSONObject();
             

                detail.put("USE_APPOINTMENT", detail_rs.getInt("USE_APPOINTMENT"));
               

                study_details.add(detail);
            }

            stmt.close();
            conn.close();
            out.println(study_details); 
        }

        else if(type.equals("LOAD_APPOINT_FIX")){

            //Load Study Details
            String SID = request.getParameter("SID");

            //Load Extra Contents
           String load_study_detail_query= "SELECT AFID, IFNULL(AFDATE,'') as AFDATE, IFNULL(DATE_FORMAT(AFDATE, '%w'), '') as AFDAY, IFNULL(TIME_FORMAT(AFTIME, '%H:%i'),'') as AFTIME, MAX FROM APPOINT_FIX WHERE  SID=" + SID;
            ResultSet detail_rs = stmt.executeQuery(load_study_detail_query);
            JSONArray study_details = new JSONArray();

            while(detail_rs.next()){
                JSONObject detail = new JSONObject();
             

                detail.put("AFID", detail_rs.getInt("AFID"));
                detail.put("DATE", detail_rs.getString("AFDATE"));
                 detail.put("AFDAY", detail_rs.getInt("AFDAY"));
                detail.put("TIME", detail_rs.getString("AFTIME"));
                detail.put("MAX", detail_rs.getInt("MAX"));

                study_details.add(detail);
            }

            stmt.close();
            conn.close();
            out.println(study_details); 
        }
    }catch(Exception  e){
   e.printStackTrace();
        out.println(e.toString());
    }
    finally{
         if(stmt!=null) { try{stmt.close();} catch(Exception e){}}  stmt.close();
         if(conn!=null) { try{conn.close();} catch(Exception e){}}  conn.close();
    }
%>

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
<%
 
    JSONParser db_parser = new JSONParser();
    Object obj = db_parser.parse(new FileReader("../config/dbconfig.json"));
    JSONObject jo = (JSONObject) obj;
        // out.println((String)jo.get("host"));
    
    String jdbcDriverValue = (String)jo.get("host");
    String dbId = (String)jo.get("username");
    String dbPass = (String)jo.get("password");
    


 
    Class.forName("com.mysql.jdbc.Driver");
    //String jdbcDriver = "jdbc:mysql://"+DB_info.get("ip")+":"+DB_info.get("port")+"/"+DB_info.get("dbName");
    String jdbcDriver = jdbcDriverValue;
    Connection conn= DriverManager.getConnection(jdbcDriver,dbId, dbPass); 
    Statement stmt =null;
    stmt = conn.createStatement();
  
    try{
        String type = request.getParameter("action");
     

        if(type.equals("load_recruiting")){

            String query = "SELECT s.SID, s.TITLE, s.SAPPL, s.SSEX, s.SNUM, s.STARGET, s.SDATE, s.EMERGENCY, s.SITEID, si.SITENAME FROM STUDY s, SITE si WHERE s.SITEID = si.SITEID and SPUBLISHED = 1 and SACTIVE=1 ORDER BY s.EMERGENCY   DESC , s.SID DESC";
        //  else if(STUDYORDER.equals("CREATEDTC")) query = "SELECT SID, TITLE,SAPPL, SSEX,SNUM,STARGET,SDATE,ORDERS, SITEID FROM STUDY WHERE SPUBLISHED = 1 ORDER BY ORDERS DESC, SCREATEDTC= "+ORDERS;
            ResultSet rs = stmt.executeQuery(query);

            JSONArray studies = new JSONArray();

            while(rs.next()){
                JSONObject study = new JSONObject();
                study.put("SID", rs.getInt(1));
                study.put("TITLE", rs.getString(2));
                study.put("SAPPL", rs.getString(3));
                study.put("SSEX", rs.getInt(4));
                study.put("SNUM", rs.getInt(5));
                study.put("STARGET", rs.getString(6));
                study.put("SDATE", rs.getString(7));
                study.put("EMERGENCY", rs.getInt(8));
                study.put("SITEID", rs.getInt(9)); 
                study.put("SITENAME", rs.getString(10)); 
                studies.add(study);
            }
            stmt.close();
            conn.close();
            out.println(studies);
        }
        else if(type.equals("load_all_recruiting")){
            
            String query = "SELECT s.SID, s.TITLE, s.SAPPL, s.SSEX, s.SNUM, s.STARGET, s.SDATE, s.EMERGENCY, si.SITENAME FROM STUDY s, SITE si WHERE s.SPUBLISHED = 1 and s.SITEID = si.SITEID and SACTIVE=1  ORDER BY s.EMERGENCY  DESC, s.SID DESC ";
        //  else if(STUDYORDER.equals("CREATEDTC")) query = "SELECT SID, TITLE,SAPPL, SSEX,SNUM,STARGET,SDATE,ORDERS, SITEID FROM STUDY WHERE SPUBLISHED = 1 ORDER BY ORDERS DESC, SCREATEDTC= "+ORDERS;
            ResultSet rs = stmt.executeQuery(query);

            JSONArray studies = new JSONArray();

            while(rs.next()){
                JSONObject study = new JSONObject();
                study.put("SID", rs.getInt(1));
                study.put("TITLE", rs.getString(2));
                study.put("SAPPL", rs.getString(3));
                study.put("SSEX", rs.getInt(4));
                study.put("SNUM", rs.getInt(5));
                study.put("STARGET", rs.getString(6));
                study.put("SDATE", rs.getString(7));
                study.put("EMERGENCY", rs.getInt(8));
                study.put("SITEID", rs.getString(9));  
                studies.add(study);
            }
            stmt.close();
            conn.close();
            out.println(studies);
        }
        else if(type.equals("load_site_list")){
            
            String query = "SELECT SITENAME FROM SITE;";
        //  else if(STUDYORDER.equals("CREATEDTC")) query = "SELECT SID, TITLE,SAPPL, SSEX,SNUM,STARGET,SDATE,ORDERS, SITEID FROM STUDY WHERE SPUBLISHED = 1 ORDER BY ORDERS DESC, SCREATEDTC= "+ORDERS;
            ResultSet rs = stmt.executeQuery(query);

            JSONArray sites = new JSONArray();

            while(rs.next()){
                JSONObject site = new JSONObject();
                site.put("SITENAME", rs.getString(1));
                sites.add(site);
            }
            stmt.close();
            conn.close();
            out.println(sites);
        }
        else if(type.equals("load_target_list")){
            
            String query = "SELECT distinct STARGET FROM STUDY WHERE SPUBLISHED = 1 and STARGET != '' ;";
        //  else if(STUDYORDER.equals("CREATEDTC")) query = "SELECT SID, TITLE,SAPPL, SSEX,SNUM,STARGET,SDATE,ORDERS, SITEID FROM STUDY WHERE SPUBLISHED = 1 ORDER BY ORDERS DESC, SCREATEDTC= "+ORDERS;
            ResultSet rs = stmt.executeQuery(query);

            JSONArray targets = new JSONArray();

            while(rs.next()){
                JSONObject target = new JSONObject();
                target.put("TARGET", rs.getString(1));
                targets.add(target);
            }
            stmt.close();
            conn.close();
            out.println(targets);
        }
        else if(type.equals("detail_load")){
               String SID = request.getParameter("SID");
            JSONArray studies = new JSONArray();

            String query = "SELECT SID, SPONSORID, PRTNO, TITLE, SAPPL, SSEX, SNUM, STARGET, SDATE, SFILE, SFILENAME, SACTIVE, SPUBLISHED, EMERGENCY FROM STUDY WHERE SID = " + SID;
            ResultSet rs = stmt.executeQuery(query);

            while(rs.next()){
                JSONObject study = new JSONObject();
                study.put("SID", rs.getInt(1));  
                study.put("SPONSORID", rs.getString(2));          
                study.put("PRTNO", rs.getString(3));
                study.put("TITLE", rs.getString(4));
                study.put("SAPPL", rs.getString(5));
                study.put("SSEX", rs.getInt(6));
                study.put("SNUM", rs.getInt(7));
                study.put("STARGET", rs.getString(8));
                study.put("SDATE", rs.getString(9));
                //study.put("SFILE", rs.getString(14));
                if(rs.getString(10)!=null) study.put("SFILE", rs.getString(10));
                else study.put("SFILE","");
                study.put("CONTEXTPATH", request.getContextPath());
                study.put("SFILENAME", rs.getString(11));
                study.put("SACTIVE", rs.getInt(12));
                study.put("SPUBLISHED", rs.getInt(13));
                study.put("EMERGENCY", rs.getInt(14));
                studies.add(study);
            }

            String query_detail = "SELECT SDTITLE, SDCONTENT FROM STUDY_DETAIL WHERE SDPUBLISHED = 1 and SID = " + SID;
            ResultSet rs_detail = stmt.executeQuery(query_detail);
            JSONArray study_details = new JSONArray();

            while(rs_detail.next()){
                JSONObject study = new JSONObject();
                study.put("TITLE", rs_detail.getString(1));
                study.put("CONTENT", rs_detail.getString(2));
                study_details.add(study);
            }

            studies.add(study_details);

            ////////// load consents ////////////////////////////////

            String query_consent = "SELECT CFILE, CVERSION, CPUBLISHDTC FROM CONSENT WHERE SID = " + SID +" order by CONSENTID  DESC";
            ResultSet rs_consent = stmt.executeQuery(query_consent);
            JSONArray consent_consents = new JSONArray();

            while(rs_consent.next()){
                JSONObject consent = new JSONObject();
                consent.put("CFILE", rs_consent.getString(1));
                consent.put("CVERSION", rs_consent.getString(2));
                consent.put("CPUBLISHDTC", rs_consent.getString(3));
                consent_consents.add(consent);
            }

            studies.add(consent_consents);

            ////////////////////////////////////////////////
            stmt.close();
            conn.close();
            out.println(studies);
            
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

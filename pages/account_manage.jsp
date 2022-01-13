<%@page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%@page import="java.net.URLDecoder" %>
<%@page import="java.io.*"%>
<%@page import="java.security.MessageDigest"%>
<%@page import="java.security.NoSuchAlgorithmException"%>
<%@page import="org.json.simple.*"%>
<%@page import="org.json.simple.parser.*"%>
<%@page import="org.json.simple.JSONObject"%>
<%@page import="org.json.simple.JSONArray"%>
<%@include file="./sendMsg/common.jsp" %>
<%@page import="com.popbill.api.PopbillException"%>


<%!
    public int randomInt(int min, int max){
        return (int)Math.floor(Math.random() * (max-min))+min;
    }

    public static String sha256(String _message) throws NoSuchAlgorithmException {
        MessageDigest md = MessageDigest.getInstance("SHA-256");
        md.update(_message.getBytes());
        
        return bytesToHex(md.digest());
    }

    public static String bytesToHex(byte[] bytes) {
        StringBuilder builder = new StringBuilder();
        for (byte b: bytes) {
          builder.append(String.format("%02x", b));
        }
        return builder.toString();
    }

    public static Boolean isValid(String _targetEmail, String _targetPhoneNumber){
        if(_targetEmail.equals("")) {
            return false;
        }
        if(_targetPhoneNumber.equals("")) {
            return false;
        }
        return true;
    }

    public static Boolean isExist(Statement _stmt, String _targetEmail, String _targetPhoneNumber) throws SQLException {
        ResultSet rs = _stmt.executeQuery("SELECT invmail FROM investigator WHERE invmail='"+_targetEmail+"' and invcellphonenum='"+_targetPhoneNumber+"'");
        String invMail = "";

        while(rs.next()){
            invMail = rs.getString(1);
        }

        if(invMail.equals("")){
            return false;
        }

        return true;
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

    //문자발송 번호 가져오기
    JSONObject messageConfigJson = (JSONObject)db_parser.parse(new FileReader("../config/message_config.json"));
    String sender = (String)messageConfigJson.get("sender");

    Connection conn= DriverManager.getConnection(jdbcDriver,dbId, dbPass); 
    Statement stmt =null;
    ResultSet rs;
    stmt = conn.createStatement();

    //Load User information

    try{
        String type = request.getParameter("action");

        if(type.equals("PASSWORD_RESET")){
            
            String targetEmail = request.getParameter("targetEmail");
            String targetPhoneNumber = request.getParameter("targetPhoneNumber");

            if(!isValid(targetEmail, targetPhoneNumber)) {
                out.println("이메일주소와 핸드폰번호를 입력해주세요.");
                return;
            }

            
            if(!isExist(stmt, targetEmail, targetPhoneNumber)) {
                out.println("해당하는 계정정보가 없습니다.");
                return;
            }

            String newPassword = String.valueOf(randomInt(10000000,100000000));
            stmt.executeUpdate("UPDATE investigator SET invpwd='"+sha256(newPassword)+"' WHERE invMail='"+targetEmail+"'");


            // 팝빌 관련 변수
            String testCorpNum = "0000000001";
            String new_msg =  "[미투리] 임시 비밀번호는 "+ newPassword + " 입니다.";
            String testUserID = "swjeong";
            String phonenum =  targetPhoneNumber;
            String receiverName = "";
            String subject = "[미투리] 비밀번호 변경 안내";
            Boolean adsYN = false;
            Date reserveDT = null;
            String requestNum = "";
            String receiptNum = null;

            // 전송
		    receiptNum = messageService.sendXMS(testCorpNum, sender, phonenum, receiverName, subject, new_msg, reserveDT, adsYN, testUserID, requestNum);

            out.println("임시 비밀번호가 문자메시지로 전송되었습니다.");
               
            stmt.close();
            conn.close();
        }else if(type.equals("AUTHENTICATION")){
            String targetEmail = request.getParameter("targetEmail");
            String targetPhoneNumber = request.getParameter("targetPhoneNumber");

            if(!isValid(targetEmail, targetPhoneNumber)) {
                out.println("이메일주소와 핸드폰번호를 입력해주세요.");
                return;
            }

            if(!isExist(stmt, targetEmail, targetPhoneNumber)) {
                out.println("해당하는 계정정보가 없습니다.");
                return;
            }

            // 인증 번호 생성
            String authenticationNumber = String.valueOf(randomInt(100000,1000000));

            // 팝빌 관련 변수
            String testCorpNum = "0000000001";
            String new_msg =  "[미투리] 인증번호는 "+ authenticationNumber + " 입니다.";
            String testUserID = "swjeong";
            String phonenum =  targetPhoneNumber;
            String receiverName = "";
            String subject = "[미투리] 인증번호 전송";
            Boolean adsYN = false;
            Date reserveDT = null;
            String requestNum = "";
            String receiptNum = null;

            // 전송
		    receiptNum = messageService.sendXMS(testCorpNum, sender, phonenum, receiverName, subject, new_msg, reserveDT, adsYN, testUserID, requestNum);

            // 쿠키 저장
            Cookie c1 = new Cookie("authenticationNumber", sha256(authenticationNumber));
            c1.setMaxAge(60*3);
            response.addCookie(c1);
            Cookie c2 = new Cookie("targetEmail", targetEmail);
            c2.setMaxAge(60*3);
            response.addCookie(c2);
            Cookie c3 = new Cookie("targetPhoneNumber", targetPhoneNumber);
            c3.setMaxAge(60*3);
            response.addCookie(c3);

            out.println("인증번호가 문자메시지로 전송되었습니다. 인증번호가 오지 않으면 입력하신 정보가 회원정보와 일치하는지 확인해 주세요.");
        }else if(type.equals("FIND_ID")){
            String targetName = URLDecoder.decode(request.getParameter("targetName"), "UTF-8");
            String targetPhoneNumber = request.getParameter("targetPhoneNumber");
            if(!isValid(targetName, targetPhoneNumber)) {
                out.println("이름과 핸드폰번호를 입력해주세요.");
                return;
            }

            String search_query = "SELECT INVMAIL FROM INVESTIGATOR WHERE INVNAME='"+targetName+"' AND INVCELLPHONENUM='"+targetPhoneNumber+"'";
            ResultSet search_rs = stmt.executeQuery(search_query);
            String INVMAIL = "";
            while(search_rs.next()){
                INVMAIL = search_rs.getString(1);
            }
            if(INVMAIL.equals("")){
                out.println("해당하는 계정정보가 없습니다.");
                return;
            }

            out.println("["+targetName+"] 님의 아이디는 ["+INVMAIL+"] 입니다.");
               
            stmt.close();
            conn.close();
        }else if(type.equals("AUTHENTICATION_ID")){
            String targetName = URLDecoder.decode(request.getParameter("targetName"), "UTF-8");
            String targetPhoneNumber = request.getParameter("targetPhoneNumber");
            if(!isValid(targetName, targetPhoneNumber)) {
                out.println("이름과 핸드폰번호를 입력해주세요.");
                return;
            }
            
            String search_query = "SELECT INVMAIL FROM INVESTIGATOR WHERE INVNAME='"+targetName+"' AND INVCELLPHONENUM='"+targetPhoneNumber+"'";
            ResultSet search_rs = stmt.executeQuery(search_query);
            String INVMAIL = "";
            while(search_rs.next()){
                INVMAIL = search_rs.getString(1);
            }
            if(INVMAIL.equals("")){
                out.println("해당하는 계정정보가 없습니다.");
                return;
            }

            // 인증 번호 생성
            String authenticationNumber = String.valueOf(randomInt(100000,1000000));
            // 팝빌 관련 변수
            String testCorpNum = "0000000001";
            String new_msg =  "[미투리] 인증번호는 "+ authenticationNumber + " 입니다.";
            String testUserID = "swjeong";
            String phonenum =  targetPhoneNumber;
            String receiverName = "";
            String subject = "[미투리] 인증번호 전송";
            Boolean adsYN = false;
            Date reserveDT = null;
            String requestNum = "";
            String receiptNum = null;
            // 전송
		    receiptNum = messageService.sendXMS(testCorpNum, sender, phonenum, receiverName, subject, new_msg, reserveDT, adsYN, testUserID, requestNum);
            // 쿠키 저장
            Cookie c1 = new Cookie("authenticationNumber11", sha256(authenticationNumber));
            c1.setMaxAge(60*3);
            response.addCookie(c1);
            Cookie c2 = new Cookie("targetName11", request.getParameter("targetName"));
            c2.setMaxAge(60*3);
            response.addCookie(c2);
            Cookie c3 = new Cookie("targetPhoneNumber11", targetPhoneNumber);
            c3.setMaxAge(60*3);
            response.addCookie(c3);
            out.println("인증번호가 문자메시지로 전송되었습니다. 인증번호가 오지 않으면 입력하신 정보가 회원정보와 일치하는지 확인해 주세요.");
        }
    }catch(Exception e){
        e.printStackTrace();
    }finally{
         if(stmt!=null) { try{stmt.close();} catch(Exception e){}}  stmt.close();
         if(conn!=null) { try{conn.close();} catch(Exception e){}}  conn.close();
    }
%>
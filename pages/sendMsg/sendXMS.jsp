<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>

<%@ include file="common.jsp" %>
<%@page import="org.json.simple.JSONObject"%>
<%@page import="org.json.simple.*"%>
<%@page import="org.json.simple.parser.*"%>
<%@page import="java.util.Date"%>
<%@page import="java.text.SimpleDateFormat"%>
<%@page import="com.popbill.api.PopbillException"%>
<%@ page import="java.net.URLDecoder" %>
<%@page import="java.io.*"%>
<%@page import="java.sql.*"%>

<%
	/*
	 * XMS(단문/장문 자동인식)를 전송합니다.
	 *  - 메시지 내용의 길이(90byte)에 따라 SMS/LMS(단문/장문)를 자동인식하여 전송합니다.
	 *  - https://docs.popbill.com/message/java/api#SendXMS
	 */


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
    
    Connection conn= DriverManager.getConnection(jdbcDriver,dbId, dbPass); 
    Statement stmt =null;
    stmt = conn.createStatement();

	int SITEID = (int)session.getAttribute("SITEID");
    int INVID = (int)session.getAttribute("INVID");
    String INVNAME = session.getAttribute("INVNAME").toString();
    String INVMAIL = session.getAttribute("INVMAIL").toString();
    String SITENAME = session.getAttribute("SITENAME").toString();

	
	
	// 팝빌회원 사업자번호
	String testCorpNum = "0000000001";
	//String new_msg = "0000000001";
	String new_msg =  URLDecoder.decode(request.getParameter("message"),"UTF-8");//URLDecoder.decode(request.getParameter("INVOFFICE"), "UTF-8");

	// 팝빌회원 아이디
	String testUserID = "swjeong";

	//문자발송 번호 가져오기
    JSONObject messageConfigJson = (JSONObject)db_parser.parse(new FileReader("../config/message_config.json"));
    String sender = (String)messageConfigJson.get("sender");
	String phonenum =  request.getParameter("phonenum2");

	// 수신번호
	// String receiver = "010123456";

	// 수신자명
	String receiverName = "";

	// 메시지 제목
	//String subject = "[임상시험 방문예약안내]";
	String subject = URLDecoder.decode(request.getParameter("title"), "UTF-8");

	// 메시지 내용, 90Byte를 기준으로 단문과 장문을 자동 인식하여 전송됨
	// String content = "문자메시지 내용";

	// 광고문자 전송여부
	Boolean adsYN = false;

	// 예약전송일시(yyyyMMddHHmmss), null인 경우 즉시전송
	Date reserveDT = null;
	//	예약전송시 아래의 코드 참조
	//	String reserveDTtxt ="20141229180000";
	//	SimpleDateFormat formatter = new SimpleDateFormat("yyyyMMddHHmmss");
	//	reserveDT = formatter.parse(reserveDTtxt);

	// 전송요청번호
	// 파트너가 전송 건에 대해 관리번호를 구성하여 관리하는 경우 사용.
	// 1~36자리로 구성. 영문, 숫자, 하이픈(-), 언더바(_)를 조합하여 팝빌 회원별로 중복되지 않도록 할당.
	String requestNum = "";

	String receiptNum = null;
	//out.println(phonenum + "    "+ new_msg);
	JSONObject result=new JSONObject();

	// SMS_LOG 저장 - CREATE
	String selectAPPLNameQuery = "select APPLNAME from applicant where APPLPHONENUM='" + phonenum + "'";
	ResultSet rs = stmt.executeQuery(selectAPPLNameQuery);
	while(rs.next()) receiverName = rs.getString(1);

	String smsLogInsertQuery = "INSERT INTO sms_log(SMS_RECEIPT_NUM, SID, SITEID, RECEIVER_NAME, RECEIVER_PHONE, MESSAGE, SAID, WHO, WHO_ID, HOW, LOGDTC) values(null,null,"+SITEID+",'"+receiverName+"','"+phonenum+"','"+new_msg+"',null,'site',"+INVID+",'CREATE', NOW())";
	stmt.executeUpdate(smsLogInsertQuery);

	try {

		receiptNum = messageService.sendXMS(testCorpNum, sender, phonenum, receiverName,
				subject, new_msg, reserveDT, adsYN, testUserID, requestNum);
				result.put("RESULT","SUCCESS" );
				result.put("RECEIPTNUM",receiptNum );
		out.println(result); 
	} catch (PopbillException pe) {
		//적절한 오류 처리를 합니다. pe.getCode() 로 오류코드를 확인하고, pe.getMessage()로 관련 오류메시지를 확인합니다.
		//예제에서는 exception.jsp 페이지에서 오류를 표시합니다.
		//throw pe;	
		result.put("RESULT","error" );
				result.put("MSG", pe.getMessage() );
				result.put("ERRORCODE",pe.getCode()  );
			out.println(result); 
	}
	
%>

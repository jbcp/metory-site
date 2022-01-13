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
<%@page import="java.util.List"%>
<%@page import="java.util.ArrayList"%>
<%@page import="java.util.Arrays"%>

<%!
    public int selectConceptId(String _answerType){
        if (_answerType.equals("Text")) return 1002;
        else if (_answerType.equals("TextArea")) return 1005;
        else if (_answerType.equals("Date")) return 1004;
        else if (_answerType.equals("YorN")) return 1001;
        else if (_answerType.equals("Selection")) return 1001;

        return 0;
    }

    public List<String> listStr_to_List(String _listStr){
        String tmp = _listStr.substring(1,_listStr.length()-1);
        tmp = tmp.replace("\"","");
        return Arrays.asList(tmp.split(","));
    }
    
    public void makeAnswer(JSONObject _answer, int _conceptId, int _answerItemGroupId, Statement _stmt, ResultSet _rs, List<String> _itemArr) throws SQLException {
        List<String> itemArr = new ArrayList<String>();
        if (_conceptId == 1002) {
            _answer.put("answerType","Text");
            _answer.put("YorN",new ArrayList<String>());
            _answer.put("selection",new ArrayList<String>());
            _answer.put("date","");
        }
        else if (_conceptId == 1005) {
            _answer.put("answerType","TextArea");
            _answer.put("YorN",new ArrayList<String>());
            _answer.put("selection",new ArrayList<String>());
            _answer.put("date","");    
        }
        else if (_conceptId == 1004) {
            _answer.put("answerType","Date");
            _answer.put("YorN",new ArrayList<String>());
            _answer.put("selection",new ArrayList<String>());
            _answer.put("date","");
        }
        else if (_conceptId == 1001) {
            _answer.put("answerType","Selection");
            // Selection 일 경우, DB에서 찾아와야함.. (ANSWER_ITEM_TEXT는 복수로 뽑힘)
            _rs = _stmt.executeQuery("SELECT ANSWER_ITEM_TEXT FROM answer_item WHERE ANSWER_ITEM_GROUP_ID="+_answerItemGroupId+" ORDER by ANSWER_ITEM_SEQ ASC");
            while(_rs.next()){
                _itemArr.add(_rs.getString(1));
            }
            _answer.put("selection", _itemArr);

        }
    }

    public int saveSIDonScreening(int _INVID, int _sid, Statement _stmt) throws SQLException {
        int screeningId=0;
        int valid=1;
        Timestamp currentTimeStamp = new Timestamp(System.currentTimeMillis());
        
        // 설문지가 이미 있는지 확인 , 몇 개가 있던 다 valid 0 만들기
        String validUpdateQuery = "UPDATE screening set VALID=0 WHERE SID="+_sid;
        _stmt.executeUpdate(validUpdateQuery);
        
        // Screening table에 SID 추가 쿼리 실행 && SCREENING_ID 저장
        String screeningInsertQuery = "Insert INTO screening(SID) values('"+_sid+"')";
        _stmt.executeUpdate(screeningInsertQuery);

        ResultSet rs = _stmt.executeQuery("SELECT last_insert_id()");
        while(rs.next()){
            screeningId = rs.getInt(1); //SCREENING_ID 저장
        }

        // log insert query
        String screeninglogInsertQuery = "insert into screening_log(SCREENING_ID, SID, VALID, INVID, `WHERE`, LOGDTC, WHAT) values("+screeningId+", "+_sid+", "+valid+", "+_INVID+", 'study_criteria', '"+currentTimeStamp.toString()+"','create')";
        _stmt.executeUpdate(screeninglogInsertQuery);

        return screeningId;
    }

    public int saveTitleonQuestion(int _INVID, String _title, int _conceptId, Statement _stmt) throws SQLException {
        int questionId = 0;
        Timestamp currentTimeStamp = new Timestamp(System.currentTimeMillis());

        // 문제 제목 추가 쿼리 실행 && SCREENING_QUESTION_ID 저장
        String answerTitleInsertQuery = "INSERT INTO question(QUESTION_CONTENT, ANSWER_TYPE_CONCEPT_ID) values('"+_title+"','"+_conceptId+"');";
        _stmt.executeUpdate(answerTitleInsertQuery);
        ResultSet rs = _stmt.executeQuery("SELECT last_insert_id()");
        while(rs.next()){
            questionId = rs.getInt(1); //questionId 저장
        }

        // log insert query
        String questionlogInsertQuery = "insert into question_log(QUESTION_ID, QUESTION_CONTENT, ANSWER_TYPE_CONCEPT_ID, INVID, `WHERE`, LOGDTC, WHAT) values("+questionId+",'"+_title+"', "+_conceptId+", "+_INVID+", 'study_criteria', '"+currentTimeStamp.toString()+"', 'create')";
        _stmt.executeUpdate(questionlogInsertQuery);

        return questionId;
    }

    public int saveItemGrouponAnswerItemGroup(int _INVID, List<String> _list, int _questionId, Statement _stmt) throws SQLException {
        int answerItemGroupId = 0;
        Timestamp currentTimeStamp = new Timestamp(System.currentTimeMillis());
        
        String itemGroupInsertQuery = "INSERT INTO answer_item_group(ANSWER_ITEM_GROUP_NAME) value('"+String.join("/",_list)+"')";
        _stmt.executeUpdate(itemGroupInsertQuery);
        ResultSet rs = _stmt.executeQuery("SELECT last_insert_id()");
        while(rs.next()){
            answerItemGroupId = rs.getInt(1); //answerItemGroupId 저장
        }

        // answeritemgroup insert query
        String answerItemGroupInsertQuery = "insert into answer_item_group_log(ANSWER_ITEM_GROUP_ID, ANSWER_ITEM_GROUP_NAME, INVID, `WHERE`, LOGDTC, WHAT) values("+answerItemGroupId+", '"+String.join("/",_list)+"', "+_INVID+", 'study_criteria', '"+currentTimeStamp.toString()+"', 'create')";
        _stmt.executeUpdate(answerItemGroupInsertQuery);

        // question update query
        String questionUpdateQuery = "update question set ANSWER_ITEM_GROUP_ID="+answerItemGroupId+" where QUESTION_ID=" + _questionId;
        _stmt.executeUpdate(questionUpdateQuery);

        // questionlog update query
        String questionlogUpdateQuery = "update question_log set ANSWER_ITEM_GROUP_ID="+answerItemGroupId+" where QUESTION_ID=" + _questionId;
        _stmt.executeUpdate(questionlogUpdateQuery);
        
        return answerItemGroupId;
    }

    public void saveItemonAnswerItem(int _INVID, List<String> _list,  int _answerItemGroupId, Statement _stmt) throws SQLException {
        Timestamp currentTimeStamp = new Timestamp(System.currentTimeMillis());
        ResultSet rs = null;

        for(int idx=0; idx<_list.size(); idx++){
            int answerItemId = 0;
            String itemInsertQuery = "INSERT INTO answer_item(ANSWER_ITEM_GROUP_ID,ANSWER_ITEM_TEXT, ANSWER_ITEM_SEQ) value('"+_answerItemGroupId+"','"+_list.get(idx)+"','"+(idx+1)+"')";
            _stmt.executeUpdate(itemInsertQuery);
            rs = _stmt.executeQuery("SELECT last_insert_id()");
            while(rs.next()){
                answerItemId = rs.getInt(1); //questionId 저장
            }

            //log insert query 
            String answerItemlogInsertQuery = "insert into answer_item_log(ANSWER_ITEM_ID, ANSWER_ITEM_GROUP_ID, ANSWER_ITEM_SEQ, ANSWER_ITEM_TEXT, INVID, `WHERE`, LOGDTC, WHAT) values("+answerItemId+", "+_answerItemGroupId+", "+(idx+1)+", '"+_list.get(idx)+"', "+_INVID+", 'study_criteria', '"+currentTimeStamp.toString()+"', 'create')";
            _stmt.executeUpdate(answerItemlogInsertQuery);
        }
    }

    public void mappingScreeningQuestion(int _INVID, int _screeningId, int _sectionSequence, int _surveySectionId, int _questionSequence, int _questionId, Statement _stmt) throws SQLException {
        int screeningQuestionId = 0;
        Timestamp currentTimeStamp = new Timestamp(System.currentTimeMillis());
        String screeningQuestionInsertQuery = "INSERT INTO screening_question(SCREENING_ID, SECTION_SEQ, SURVEY_SECTION_ID, QUESTION_SEQ, QUESTION_ID) values('"+_screeningId+"','"+_sectionSequence+"','"+_surveySectionId+"','"+_questionSequence+"','"+_questionId+"')";
        _stmt.executeUpdate(screeningQuestionInsertQuery);
        ResultSet rs = _stmt.executeQuery("SELECT last_insert_id()");
        while(rs.next()){
            screeningQuestionId = rs.getInt(1); //questionId 저장
        }
        
        //log insert query
        String screeningQuestionlogInsertQuery = "insert into screening_question_log(SCREENING_QUESTION_ID, SCREENING_ID, SECTION_SEQ, SURVEY_SECTION_ID, QUESTION_SEQ, QUESTION_ID, INVID, `WHERE`, LOGDTC, WHAT) values("+screeningQuestionId+", "+_screeningId+", "+_sectionSequence+", "+_surveySectionId+", "+ _questionSequence+", "+_questionId+", "+_INVID+", 'study_criteria', '"+currentTimeStamp.toString()+"', 'create')";
        _stmt.executeUpdate(screeningQuestionlogInsertQuery);
    }

    public void saveQuestionOption(int _INVID, int _questionId, int _screeningId, int _sid, int _criticalInt, String _correctAnswer, Statement _stmt) throws SQLException {
        int questionOptionId = 0;
        Timestamp currentTimeStamp = new Timestamp(System.currentTimeMillis());

        String correctAnswerInsertQuery = "INSERT INTO question_option(questionid, screeningid, sid, required, inv_answer) values("+_questionId+", "+_screeningId+", "+_sid+", "+_criticalInt+", '"+_correctAnswer+"')";
        _stmt.executeUpdate(correctAnswerInsertQuery);
        ResultSet rs = _stmt.executeQuery("SELECT last_insert_id()");
        while(rs.next()){
            questionOptionId = rs.getInt(1); //questionId 저장
        }

        //question_option_log insert query
        String questionOptionlogInsertQuery = "insert into question_option_log(question_option_id, questionid, screeningid, sid, required, inv_answer, INVID, `WHERE`, LOGDTC, WHAT) values("+questionOptionId+", "+_questionId+", "+_screeningId+", "+_sid+", "+_criticalInt+", '"+_correctAnswer+"', "+_INVID+", 'study_criteria', '"+currentTimeStamp.toString()+"', 'create')";
        _stmt.executeUpdate(questionOptionlogInsertQuery);
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

    Connection conn= DriverManager.getConnection(jdbcDriver,dbId, dbPass); 
    Statement stmt =null;
    ResultSet rs;
    stmt = conn.createStatement();
    
    //Load User information
    int INVID = (int)session.getAttribute("INVID"); 

    try{
        String type = request.getParameter("action");
        int sid = Integer.parseInt(request.getParameter("sid")); //9

        if(type.equals("SAVE_QUESTION")){
            String criterias = new String(request.getParameter("criterias").getBytes("8859_1"), "UTF-8");
            JSONParser parser = new JSONParser();
            JSONArray criteriaArray = (JSONArray)parser.parse(criterias);
            JSONArray pis = new JSONArray();

            // 변수 준비
            int answerItemGroupId = 0;
            int screeningId = 0;

            // Screening table에 SID 추가 쿼리 실행 && SCREENING_ID 저장
            screeningId = saveSIDonScreening(INVID, sid, stmt);
            out.println("saveSIDonScreening");
            
            /**************** 각 Criteria별로 쿼리 실행 시작 ****************/
            for(int idxNum=0; idxNum<criteriaArray.size(); idxNum++){
                JSONObject criteria = (JSONObject)criteriaArray.get(idxNum);
                String title = criteria.get("title").toString();
                String correctAnswer = criteria.get("correctAnswer").toString();
                Boolean critical = (Boolean) criteria.get("critical");
                int criticalInt = critical ? 1:0;
                JSONObject answer = (JSONObject)criteria.get("answer");
                String answerType = answer.get("answerType").toString();
                
                List<String> YorN;
                List<String> Selection;

                // for database columns
                int conceptId = 0;
                int questionId = 0;
                int sectionSequence = 1; // 현재 고정함
                int surveySectionId = 6; // 현재 고정함
                int questionSequence = idxNum+1; // 1~n;

                // conceptId 설정
                conceptId = selectConceptId(answerType);
                out.println("selectConceptId");
                
                // listStr to YorN(strList)
                String listStr = answer.get("YorN").toString();
                YorN = listStr_to_List(listStr);

                // listStr to Selection(strList)
                listStr = answer.get("selection").toString();
                Selection = listStr_to_List(listStr);
                
                // 문제 제목 추가 쿼리 실행 && SCREENING_QUESTION_ID 저장
                questionId = saveTitleonQuestion(INVID, title, conceptId, stmt);
                out.println("saveTitleonQuestion");

                // ANSWER ITEM 추가 쿼리 실행 필요한 경우(YorN)
                if (answerType.equals("YorN")){
                    // ANSWER ITEM GROUP 추가 쿼리 실행
                    answerItemGroupId = saveItemGrouponAnswerItemGroup(INVID, YorN, questionId, stmt);
                    out.println("YorN1");

                    // ANSWER ITEM 추가 쿼리 실행
                    saveItemonAnswerItem(INVID, YorN, answerItemGroupId, stmt);
                    out.println("YorN2");
                }

                // ANSWER ITEM 추가 쿼리 실행 필요한 경우(Selection)
                else if (answerType.equals("Selection")){
                    // ANSWER ITEM GROUP 추가 쿼리 실행
                    answerItemGroupId = saveItemGrouponAnswerItemGroup(INVID, Selection, questionId, stmt);
                    out.println("Selection1");
                    // ANSWER ITEM 추가 쿼리 실행
                    saveItemonAnswerItem(INVID, Selection, answerItemGroupId, stmt);
                    out.println("Selection2");
                }
                
                // Text 일 때, 미정
                else if (answerType.equals("Text")){
                    out.println("Text");
                }
                // TextArea 일 때, 미정
                else if (answerType.equals("TextArea")){

                }
                // Date 일 때, 미정
                else if (answerType.equals("Date")){

                }
                         

                // Screening_question mapping 추가 쿼리 실행
                mappingScreeningQuestion(INVID, screeningId, sectionSequence, surveySectionId, questionSequence, questionId, stmt);
                out.println("mappingScreeningQuestion");

                // 정답 저장 쿼리 실행
                saveQuestionOption(INVID, questionId, screeningId, sid, criticalInt, correctAnswer, stmt);
                out.println("saveQuestionOption");

                out.println("끝");

            }/**************** 각 Criteria별로 쿼리 실행 종료 ****************/
               
            stmt.close();
            conn.close();
        }else if (type.equals("LOAD_QUESTION")) {

            // SCREENING_ID 찾기 FROM SCREENING 테이블
            rs = stmt.executeQuery("SELECT SCREENING_ID FROM SCREENING WHERE SID="+sid+" and VALID=1");
            int screeningId = 0;
            while(rs.next()){
                screeningId = rs.getInt(1);
            }
            
            // QUESTION_ID 찾기 FROM SCREENING_QUESTION 테이블(복수일 수 있음)
            List<Integer> questionIdArr = new ArrayList(); // add, get으로 value manipulation
            rs = stmt.executeQuery("SELECT QUESTION_ID FROM SCREENING_QUESTION WHERE SCREENING_ID="+screeningId);
            while(rs.next()){
                questionIdArr.add(rs.getInt(1));
            }

            // Question제목|ANSWER_TYPE_CONCEPT_ID|ANSWER_ITEM_GROUP_ID 가져오기, QUESTION table에서 SELECT 쿼리 실행 (scrreingIdArr size()만큼)
            JSONArray criteriaArray = new JSONArray(); // 문제를 저장할 Array*
            String title = "";
            int conceptId = 0;
            int answerItemGroupId = 0;
            String correctAnswer = "";
            int criticalInt = 0;
            Boolean critical = false;

            /**************** 각 Question별로 쿼리 실행 시작 ****************/
            for (int idx=0; idx<questionIdArr.size(); idx++) {
                rs = stmt.executeQuery("SELECT QUESTION_CONTENT, ANSWER_TYPE_CONCEPT_ID, ANSWER_ITEM_GROUP_ID FROM QUESTION WHERE QUESTION_ID="+questionIdArr.get(idx));
                while(rs.next()){
                    JSONObject criteria = new JSONObject();
                    JSONObject answer = new JSONObject();
                    title = rs.getString(1);
                    conceptId = rs.getInt(2);
                    answerItemGroupId = rs.getInt(3);
                    List<String> itemArr = new ArrayList();

                    // answer json 준비
                    makeAnswer(answer, conceptId, answerItemGroupId, stmt, rs, itemArr);

                    // 문항이 크리티컬한가? && correctAnswer
                    rs = stmt.executeQuery("SELECT required, inv_answer FROM question_option where questionid="+questionIdArr.get(idx));
                    while(rs.next()){
                        criticalInt = rs.getInt(1);
                        critical = (criticalInt != 0);
                        correctAnswer = rs.getString(2);
                    }
                    
                    //정답 넣기
                    criteria.put("critical", critical);
                    criteria.put("correctAnswer", correctAnswer);

                    /* criteria 개별 Json 준비 */
                    criteria.put("title", title);
                    criteria.put("subtitle","기본");
                    criteria.put("answer", answer);

                    // add on criteriaArray
                    criteriaArray.add(criteria);
                }
            }

            out.println(criteriaArray);
        }
    }catch(Exception e){
        e.printStackTrace();
    }finally{
         if(stmt!=null) { try{stmt.close();} catch(Exception e){}}  stmt.close();
         if(conn!=null) { try{conn.close();} catch(Exception e){}}  conn.close();
    }
%>

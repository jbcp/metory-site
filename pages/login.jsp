<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>

<%
session.setMaxInactiveInterval(2);
%>

<!doctype html>
<html lang="ko">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=yes">
    <link rel="stylesheet" href="../assets/lib/bootstrap/css/bootstrap.min.css">
    <link rel="stylesheet" href="../assets/css/app.css">
    <link rel="stylesheet" href="../assets/css/modern.css">
    <link rel="stylesheet" href="../assets/css/custom.css">
    <link rel="stylesheet" type="text/css" href="../assets/css/KoPubDotum.css">
    <script src="../assets/lib/jquery/jquery.min.js" type="text/javascript"></script>
    <title>METORY (연구자용)</title>
    <script type="text/javascript">

        $(document).ready(function(){
            $('#navbar').load('navbar.html');
            $('#footer').load('footer.html');

            // var error_message = document.getElementById("error_message");

            // <% if (request.getParameter("error") != null) { %>
            //     while(error_message.hasChildNodes()) error_message.removeChildNodes(error_message.firstNodes);
            //     error_message.appendChild(document.createTextNode("가입하지 않은 아이디이거나, 잘못된 비밀번호입니다."));
            // <% }     
            // %>


        })

    </script>
    <style>
      .modal-header {
        border-bottom: none;
      }
      .modal-footer {
        border-top: none;
      }
    </style>
  </head>
  <body>
    <div id="navbar"></div>
    <div class="container mt-3  p-0">

            <div class="card w-100 justify-content-center align-items-center" >
                <div class="card-body col-12" style="min-width:400px; max-width:400px; ">
                    <form class="form-signin p-2" style="text-align: center;" method="post" id="loginForm" name="loginForm" action="authentication.jsp">
                      <h1 class="h3 mb-5 mt-5 font-weight-bold">임상연구 체인플랫폼</h1>
                      <label for="inputEmail" class="sr-only" >Email address</label>
                      <input type="email" id="inputEmail" name="id" class="form-control mb-4" placeholder="Email address" style="border-radius: 0px;" required autofocus>
                      <label for="inputPassword" class="sr-only">Password</label>
                      <input type="password" id="inputPassword" name="pw" class="form-control mb-1" placeholder="Password" style="border-radius: 0px;" required>
                      
                      <span style="color:red" id="error_message"></span>
                      <button class="btn btn-lg btn-primary mt-3 mb-5" type="submit" style=" width:100px;" >로그인</button>
                      
                      <div class="row">
                        <div class="col-xs-4 col-md-6 border-right">
                                <a style="color:#2c7be5;" role="findId" data-toggle="modal" data-target="#findIdModal">아이디 찾기</a>
                        </div>
                        <div class="col-xs-6 col-md-6">
                          <a style="color:#2c7be5;" role="passwordReset" data-toggle="modal" data-target="#passwordResetModal">비밀번호 찾기</a>
                        </div>
                      </div>

                      <!-- Modal -->
                        <div class="modal fade" id="findIdModal" tabindex="-1" role="dialog" aria-labelledby="findIdModalLabel" aria-hidden="true">
                            <div class="modal-dialog modal-sm">
                                <div class="modal-content">
                                    <div class="modal-body">
                                        <div class="row">
                                            <h4 class="col-sm-12 text-center">아이디 찾기</h4>
                                        </div>
                                        <div class="row ml-2">
                                            <span class="">이름</span>
                                        </div>
                                        <div class="row ml-2 mr-2">
                                            <input type="text" class="form-control col-sm-12 mb-2" id="targetName" />
                                        </div>
                                        <div class="row ml-2">
                                            <span class="">핸드폰 번호</span>
                                        </div>
                                        <div class="row ml-2 mr-2">
                                            <input type="text" class="form-control col-sm-8 mb-2" id="targetPhoneNumber_id" />
                                            <button type="button" id="authenticationNumberSendButton_id" class="col-sm-4 btn btn-primary mb-2" onclick="getAuthenticationNumber_id()">인증번호 발송</button>
                                        </div>
                                        <div class="row ml-2">
                                            <span class="">인증번호</span>
                                        </div>
                                        <div class="row ml-2 mr-2">
                                            <input type="text" class="form-control col-sm-8 mb-2 pr-1" id="authenticationNumber_id" />
                                            <button type="button" id="setAuthenticationNumberButton_id" class="col-sm-4 btn btn-primary mb-2" onclick="setAuthenticationNumber_id()">확인</button>
                                        </div>
                                        <div class="row ml-2 mr-2">
                                            <button type="button" id="findIdButton" class="col-sm-12 btn btn-primary mb-2" onclick="findId()" disabled>찾기</button>
                                        </div>
                                        <div class="row ml-2 mr-2">
                                            <button type="button" class="col-sm-12 btn btn-default" data-dismiss="modal">취소</button>                            
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>

                      <div class="modal fade" id="passwordResetModal" tabindex="-1" role="dialog" aria-labelledby="passwordResetModalLabel" aria-hidden="true">
                        <div class="modal-dialog modal-sm">
                          <div class="modal-content">
                            <div class="modal-body">
                              <div class="row">
                                <h4 class="col-sm-12 text-center">비밀번호 찾기</h4>
                              </div>
                              <div class="row ml-2">
                                <span class="">이메일 주소</span>
                              </div>
                              <div class="row ml-2 mr-2">
                                <input type="text" class="form-control col-sm-12 mb-2" id="targetEmail" />
                              </div>
                              <div class="row ml-2">
                                <span class="">핸드폰 번호</span>
                              </div>
                              <div class="row ml-2 mr-2">
                                <input type="text" class="form-control col-sm-8 mb-2" id="targetPhoneNumber" />
                                <button type="button" id="authenticationNumberSendButton" class="col-sm-4 btn btn-primary mb-2" onclick="getAuthenticationNumber()">인증번호 발송</button>
                              </div>
                              <div class="row ml-2">
                                <span class="">인증번호</span>
                              </div>
                              <div class="row ml-2 mr-2">
                                <input type="text" class="form-control col-sm-8 mb-2 pr-1" id="authenticationNumber" />
                                <button type="button" id="setAuthenticationNumberButton" class="col-sm-4 btn btn-primary mb-2" onclick="setAuthenticationNumber()">확인</button>
                              </div>
                              <div class="row ml-2 mr-2">
                                <button type="button" id="passwordResetButton" class="col-sm-12 btn btn-primary mb-2" onclick="resetPassword()" disabled>임시비밀번호 발급</button>
                              </div>
                              <div class="row ml-2 mr-2">
                                <button type="button" class="col-sm-12 btn btn-default" data-dismiss="modal">취소</button>                            
                              </div>
                          </div>
                        </div>
                      </div>
                    </form>        
                </div>
            </div>
        </div>
    </div>
    <div id="footer" class="container mt-5 pt-5"></div>

    <script src="../assets/js/app.js"></script>
    <%-- <script src="assets/lib/bootstrap/js/bootstrap.min.js"></script> --%>
    
 <script type="text/javascript">
    var Msg ='<%=session.getAttribute("error message")%>';
    console.log(Msg);

    if (Msg != "null") {  
      function alertName(){
        alert(Msg);
      }
    }



    function resetPassword(){
      var targetEmail = document.getElementById('targetEmail').value;
      var targetPhoneNumber = document.getElementById('targetPhoneNumber').value;
      var xhttp = new XMLHttpRequest();
      xhttp.onreadystatechange = function () {
        if (this.readyState == this.DONE && this.status == 200) {
            var responseString = xhttp.responseText.trim();
            alert(responseString);
            if(responseString === "임시 비밀번호가 문자메시지로 전송되었습니다."){
              $('#passwordResetModal').modal("hide");

            }
        }
      }
      xhttp.open("POST", "./account_manage.jsp", true);
      xhttp.setRequestHeader('Content-type', 'application/x-www-form-urlencoded');
      xhttp.send("action=PASSWORD_RESET&&targetEmail="+targetEmail+"&&targetPhoneNumber="+targetPhoneNumber);
    }

    function getAuthenticationNumber(){
      var targetEmail = document.getElementById('targetEmail').value;
      var targetPhoneNumber = document.getElementById('targetPhoneNumber').value;
      var xhttp = new XMLHttpRequest();
      xhttp.onreadystatechange = function () {
        if (this.readyState == this.DONE && this.status == 200) {
            var responseString = xhttp.responseText.trim();
            alert(responseString);
        }
      }
      xhttp.open("POST", "./account_manage.jsp", true);
      xhttp.setRequestHeader('Content-type', 'application/x-www-form-urlencoded');
      xhttp.send("action=AUTHENTICATION&&targetEmail="+targetEmail+"&&targetPhoneNumber="+targetPhoneNumber);
    }

    function setAuthenticationNumber(){
      var targetEmail = document.getElementById('targetEmail').value;
      var targetPhoneNumber = document.getElementById('targetPhoneNumber').value;
      var authenticationNumber = document.getElementById('authenticationNumber').value;      
      
      if (sha256(authenticationNumber) === getCookieValue('authenticationNumber')) {
        alert("확인되었습니다.");
        document.getElementById('passwordResetButton').disabled=false;
        document.getElementById('targetEmail').disabled='disabled';
        document.getElementById('targetPhoneNumber').disabled='disabled';
        document.getElementById('authenticationNumber').disabled='disabled';
        document.getElementById('authenticationNumberSendButton').disabled='disabled';
        document.getElementById('setAuthenticationNumberButton').disabled='disabled';
      }else{
        alert("인증번호를 다시 확인해주세요.");
      }
      
    }
    

    function findId(){
        var targetName = document.getElementById('targetName').value;
        var targetPhoneNumber = document.getElementById('targetPhoneNumber_id').value;
        var xhttp = new XMLHttpRequest();
        xhttp.onreadystatechange = function () {
            if (this.readyState == this.DONE && this.status == 200) {
                var responseString = xhttp.responseText.trim();
                alert(responseString);
            }
        }
        xhttp.open("POST", "./account_manage.jsp", true);
        xhttp.setRequestHeader('Content-type', 'application/x-www-form-urlencoded');
        xhttp.send("action=FIND_ID&&targetName="+escape(encodeURIComponent(targetName))+"&&targetPhoneNumber="+targetPhoneNumber);
    }
    function getAuthenticationNumber_id(){
        var targetName = document.getElementById('targetName').value;
        var targetPhoneNumber = document.getElementById('targetPhoneNumber_id').value;
        var xhttp = new XMLHttpRequest();
        xhttp.onreadystatechange = function () {
            if (this.readyState == this.DONE && this.status == 200) {
                var responseString = xhttp.responseText.trim();
                alert(responseString);
            }
        }
        xhttp.open("POST", "./account_manage.jsp", true);
        xhttp.setRequestHeader('Content-type', 'application/x-www-form-urlencoded');
        xhttp.send("action=AUTHENTICATION_ID&&targetName="+escape(encodeURIComponent(targetName))+"&&targetPhoneNumber="+targetPhoneNumber);
    }
    function setAuthenticationNumber_id(){
        var targetName = document.getElementById('targetName').value;
        var targetPhoneNumber = document.getElementById('targetPhoneNumber_id').value;
        var authenticationNumber = document.getElementById('authenticationNumber_id').value;      
    
        if (sha256(authenticationNumber) === getCookieValue('authenticationNumber11')) {
            alert("확인되었습니다.");
            document.getElementById('findIdButton').disabled=false;
            document.getElementById('targetName').disabled='disabled';
            document.getElementById('targetPhoneNumber_id').disabled='disabled';
            document.getElementById('authenticationNumber_id').disabled='disabled';
            document.getElementById('authenticationNumberSendButton_id').disabled='disabled';
            document.getElementById('setAuthenticationNumberButton_id').disabled='disabled';
        }else{
          alert("인증번호를 다시 확인해주세요.");
        }
    }
    

    $('#targetPhoneNumber').keydown(function(event) {
      var key = event.charCode || event.keyCode || 0;
      $text = $(this);
      if (key === 13) getAuthenticationNumber();
      else if (key !== 8 && key !== 9) {
        if ($text.val().length === 3) {
          $text.val($text.val() + '-');
        }
        if ($text.val().length === 8) {
          $text.val($text.val() + '-');
        }
        if ($text.val().length > 12){
          $text.val($text.val().substring(0,$text.val().length-1));
        }
      }
      return (key == 8 || key == 9 || key == 46 || (key >= 48 && key <= 57) || (key >= 96 && key <= 105));
    });
    
    $('#targetPhoneNumber_id').keydown(function(event) {
        var key = event.charCode || event.keyCode || 0;
        $text = $(this);
        if (key === 13) getAuthenticationNumber_id();
        else if (key !== 8 && key !== 9) {
            if ($text.val().length === 3) {
                $text.val($text.val() + '-');
            }
            if ($text.val().length === 8) {
                $text.val($text.val() + '-');
            }
            if ($text.val().length > 12){
                $text.val($text.val().substring(0,$text.val().length-1));
            }
        }
        return (key == 8 || key == 9 || key == 46 || (key >= 48 && key <= 57) || (key >= 96 && key <= 105));
    });

    const getCookieValue = (key) => {
      let cookieKey = key + "="; 
      let result = "";
      const cookieArr = document.cookie.split(";");
      
      for(let i = 0; i < cookieArr.length; i++) {
        if(cookieArr[i][0] === " ") {
          cookieArr[i] = cookieArr[i].substring(1);
        }
        
        if(cookieArr[i].indexOf(cookieKey) === 0) {
          result = cookieArr[i].slice(cookieKey.length, cookieArr[i].length);
          return result;
        }
      }
      return result;
    }

    $('#passwordResetModal').on('hidden.bs.modal', function () {
        document.getElementById('targetEmail').value="";
        document.getElementById('targetPhoneNumber').value="";
        document.getElementById('authenticationNumber').value="";
        document.getElementById('passwordResetButton').disabled=true;
        document.getElementById('targetEmail').disabled=false;
        document.getElementById('targetPhoneNumber').disabled=false;
        document.getElementById('authenticationNumber').disabled=false;
        document.getElementById('authenticationNumberSendButton').disabled=false;
        document.getElementById('setAuthenticationNumberButton').disabled=false;
        $('#passwordResetModal').trigger('focus')
    })

    $('#findIdModal').on('hidden.bs.modal', function () {
        document.getElementById('targetName').value="";
        document.getElementById('targetPhoneNumber_id').value="";
        document.getElementById('authenticationNumber_id').value="";
        document.getElementById('findIdButton').disabled=true;
        document.getElementById('targetName').disabled=false;
        document.getElementById('targetPhoneNumber_id').disabled=false;
        document.getElementById('authenticationNumber_id').disabled=false;
        document.getElementById('authenticationNumberSendButton_id').disabled=false;
        document.getElementById('setAuthenticationNumberButton_id').disabled=false;
        $('#findIdModal').trigger('focus')
    })

 </script> 


<script type="text/javascript"> window.onload = alertName; </script>
<script type="text/javascript" language="javascript" src="../assets/js/sha256.min.js"></script>
  </body>
</html>
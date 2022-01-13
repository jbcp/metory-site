# metory-dapp

METORY - The real-world feasibility of a blockchain-based dynamic consent platform 



### Installation 

### 버전

```
apache-tomcat(8.0.0)
OpenJDK8
```



### lib

- Server-side

  - catalina-ssi

- Java API 기능 확장

  - commons-lang-2.6
  - commons-logging-1.2

- 파일업로드

  - cos

- 일괄처리 컴파일러

  - ecj-4.18

- JSON

  - gson-2.3
  - json-simple-1.1.1

- 블록체인 연결

  - JbcpBCRequest-0.0.1

- DB 연결

  - mysql-connector-java-5.1.35-bin

- PDF 관련

  - pdfbox-2.0.23
  - pdfbox-tools-2.0.23
  - fontbox-2.0.23

- 기타 및 의존적인 라이브러리

  - jaspic-api
  - tomcat-i18n-cs
  - tomcat-i18n-de
  - tomcat-i18n-ko
  - tomcat-i18n-pt-BR
  - tomcat-i18n-ru
  - tomcat-i18n-zh-CN
  - font-asian-7.1.14

  

### 설정파일 (config)

```bash
#설정파일 config 폴더를 tomcat 설치된 폴더로 이동

#DATABASE DDL 파일 경로 
config/DATABASE_DDL.txt

#설정항목
/config/dbconfig.json : 데이터베이스 연결 정보 정의 파일
/config/ips.json : site/dapp/subject/apipush 서버의 주소 정의 파일
/config/message_config.json : 실시기관ID 별 문자 발송 대표번호 정의 파일
/webapps/site/pages/sendMsg/common.jsp : 팝빌 사용자 인증 정보(아이디, 비밀키)
```




## Acknowledgement

*This research was supported by a grant from the Korea Health Technology R&D Project through the Korea Health Industry Development Institute (KHIDI), funded by the Ministry of  Health & Welfare, Republic of Korea (Grant Number: HI19C0332).*

---

Copyright©2021, All Rights Reserved by Center for Clinical Pharmacology and Biomedical Research Institute, Jeonbuk National University Hospital, Jeonju, Republic of Korea,  Clinical Trial Center, Seoul National University Hospital, Seoul, Republic of Korea


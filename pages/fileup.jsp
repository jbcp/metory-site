<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.sql.*"%>
<%@ page import="org.json.simple.JSONArray"%>
<%@ page import="org.json.simple.JSONObject"%>
<%@ page import="java.net.URLDecoder" %>
<%@ page import="java.io.*" %>
<%@ page import="java.util.*" %>
<%@ page import="com.oreilly.servlet.*" %>
<%@page import="java.security.MessageDigest"%>

<%
    int SITEID = (int)session.getAttribute("SITEID");    
    String rootPath = request.getSession().getServletContext().getRealPath("/");
    rootPath = rootPath.replaceAll("pages/","");

    String uploadPath = rootPath+"upload"+File.separator+SITEID;

   File ProjectDir = new File(uploadPath);
    if(! ProjectDir.exists())
    {
        ProjectDir.mkdir();
     }


    int maxSize = 1024 * 1024 * 10; 

    String name = "";
    String subject = "";

    String fileName1 = ""; 
    String originalName1 = "";
    long fileSize = 0; 
    String fileType = ""; 
    MultipartRequest multi = null;

    try{
        String type= request.getParameter("type");

        multi = new MultipartRequest(request,uploadPath,maxSize,"utf-8");
        Enumeration files = multi.getFileNames();

        while(files.hasMoreElements()){
            String file1 = (String)files.nextElement();
            originalName1 = multi.getOriginalFileName(file1);
            fileName1 = multi.getFilesystemName(file1); 
            fileType = multi.getContentType(file1);

            File file = multi.getFile(file1);
            fileSize = file.length();
        }

	 	long millis = System.currentTimeMillis();
        String[] arr=originalName1.split("[.]");

        String extention=arr[arr.length-1];
       
		File file = new File(uploadPath +"/"+ type+"_"+millis+"."+extention);

		//String fileName = originalName1;
		
		File oldFile = new File(uploadPath +"/"+ originalName1);
		//File newFile = new File(uploadPath +"/"+ fileName); 
		
        boolean success = oldFile.renameTo(file);
        if ( !success ) {
           // newFile.delete();
			oldFile.renameTo(file);
        }
        
        JSONObject fileJobj= new JSONObject();      
        fileJobj.put("FILENAME","/upload/"+SITEID +"/"+type+"_"+ millis+"."+extention);

        //동의서 파일을 업로드 하는 경우, sha256 해시값을 생성하여 반환한다.
        if(type.equals("c")){
            FileInputStream input = new FileInputStream(file);
            MessageDigest md5 = MessageDigest.getInstance("SHA-256");
            // MessageDigest md5 = MessageDigest.getInstance("MD5");
            byte[] buffer = new byte[10240];

            for (int length = 0; (length = input.read(buffer)) > 0;) {
                md5.update(buffer, 0, length);
            }     

            byte[] hash = md5.digest();
            // You may want to convert the hash to hex afterwards.

            StringBuilder hex = new StringBuilder(hash.length * 2);

            for (byte b : hash) {
                if ((b & 0xff) < 0x10) {
                    hex.append("0");
                }

                hex.append(Integer.toHexString(b & 0xff));
            }

            String hexString = hex.toString();
            fileJobj.put("FILEHASH",hexString);
        }

		out.println(fileJobj);//type=r means recruit, type=c->consent 
	

    }catch(Exception e){

        e.printStackTrace();
        out.println(e.toString());
    }
   
%>



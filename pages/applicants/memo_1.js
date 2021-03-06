'<div class="d-flex flex-row">'+
    '<div id="memo_flex_'+SAID_CLICKED+'" class= "p-2" style="text-align:left; width:500px;">'+
        '<h4 class="mt-1" style="font-size:20px; font-weight:bold">Q&A</h4>'+
        '<div id="memo_div_'+SAID_CLICKED+'" class="card card-body mb-0 border" style="height: 300px; border-radius:0px; text-align:left; min-width:500px; overflow-y:scroll; border-bottom:transparent !important;">'+
        '</div>' +
        '<div id="memo_input_div_'+SAID_CLICKED+'" class="input-group" style="min-width:500px">'+
            '<textarea class="form-control form-control-sm" rows="3" type="text" placeholder = "대답을 입력하세요." aria-describedby="add_memo_'+SAID_CLICKED+'" id="listmemo_content_'+SAID_CLICKED+'" style="border-radius:0px; resize:none"></textarea>'+
            '<div class="input-group-append">'+
                '<button class="btn btn-primary btn-lg p-3" type="button" id="add_memo_'+SAID_CLICKED+'" style="border-radius:0px; font-weight:bold;" onclick="ADD_MEMO(id);">등록</button>'+
            '</div>'+
        '</div>'+
    '</div>'+
    '<div class="p-2 ml-4" style="text-align:left">'+
        '<h4 style="font-size:20px; font-weight:bold">상태</h4>'+
        '<div class="form-group">'+
            '<select class="form-control" onchange="SELECTED(id)" id="status_SELECT_'+SAID_CLICKED+'" style="border-radius:0px">'+
                '<option value="1">신청</option>'+
                '<option value="2">예약된 대상자</option>'+
                '<option value="3">임상연구 참여불가</option>'+
                '<option value="4">스크리닝</option>'+
                '<option value="5">예비시험 대상자</option>'+
                '<option value="6">시험참여</option>'+
                '<option value="7">중도탈락</option>'+
                '<option value="8">종료</option>'+
            '</select>'+
        '</div>'+
        '<h4 class="mt-4" style="font-size:20px; font-weight:bold">설정</h4>'+
        '<form class="form-inline">'+
            '<a class="btn btn-outline-primary mr-2" href="#" id="VISIT_BTN_'+SAID_CLICKED+'_'+APPLNAME_CLICKED+'_'+APPLVISIT_CLICKED+'" onclick="VISIT(id)" style="border-radius:0px; width:100px; font-weight:bold;"> 일정 </a>'
        '</form>'+
    '</div>'+
'</div>'
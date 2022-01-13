/*!
 * Beagle v1.7.1
 * https://foxythemes.net
 *
 * Copyright (c) 2019 Foxy Themes
 */

      //Select2 init
      $('.select2').select2({
        width: '100%'
      });
      
      //Select2 tags init
      $('.tags').select2({tags: true, width: '100%'});
  

      //Filters
      $.fn.dataTable.ext.search.push(
        function( settings, searchData, index, rowData, counter ) {
          //Select2        
          var filter_project = $('.select2').val();
          var appl = $(settings.aoData[index].anCells[0]).data('appl');
    
          //Status
        //   var filter_to_do = $('#toDo').is(':checked');
        //   var filter_in_progress = $('#inProgress').is(':checked');
        //   var filter_in_review = $('#inReview').is(':checked');
        //   var filter_done = $('#done').is(':checked');
          var status = $(settings.aoData[index].nTr).attr('ssex').split(" ");
          console.log(status)

          var filter_male = $('#male').is(':checked');
          var filter_female = $('#female').is(':checked');
          var filter_both = $('#both').is(':checked');

          //Conditional filters
          if( !(filter_project == appl || filter_project == 'All') ){ return false; }
          if( !(filter_male == false  && filter_female == false && filter_both == false || filter_male == true && status[1] == '남성' || filter_female == true && status[1] == '여성' || filter_both == true && status[1] == '남녀모두') ){ return false; }
  
          return true;
  
        }
      );
      
    //   //Table init
    //   var table = $('#studies_table').DataTable({
    //     pageLength: 5,
    //     dom:  "<'row be-datatable-body'<'col-sm-12'tr>>" +
    //           "<'row be-datatable-footer'<'col-sm-5'i><'col-sm-7'p>>"
    //   });
  
      //Select2 event
    //   $('.select2').on('change', function() {
    //       console.log("chan")
    //     table.draw();
    //   });
  
    //   //Status
    //   $('#male, #female, #both').on('click', function(){
    //       console.log("change")
    //     table.draw();
    //   });

  
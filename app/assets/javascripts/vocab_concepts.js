$(document).on('turbolinks:load', function(){

  $('.concepts_selectize').selectize({
    valueField: 'value',
    labelField: 'name',
    searchField: ['name'],
    placeholder: 'Search vocabularies for concepts...',
    create: false,
    load: function(query, callback) {
      if (!query.length) return callback();
      $.ajax({
        url: "/concepts/search",
        data: { q: query },
        dataType: "json",
        type: 'GET',
        error: function(res){
          callback();
        },
        success: function(res) {
          console.log(res);
          callback(res.slice(0,10));
        }
      })
    },
    render: {
      option: function(item, escape) {
        return '<div>' + '<strong>' + escape(item.name) + '</strong>' +
                  '<p class="text-small">' + '<em>' + escape(item.parents) + '</em>' + '</p>' +
                  '<p class="text-small">' + escape(item.note) + '</p>' +
               '</div>'
      }
    }
  });
  $('.item').each(function( index ) {
    $(this).text($( this ).text().split(';')[0]);
  });
});
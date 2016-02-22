$(document).ready(function() {
  var values = document.URL.split('/');
  $('header select').val('/' + values[3] + '/' + values[4]);
});

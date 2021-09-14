/**
  ** ADAPTED from clever bootstrap responsive tabs code at:
  *     https://github.com/localnetwork/bootstrap4-responsive-tabs
  *
  *  See more docs at companion CSS file at ./app/assets/stylesheets/responsive-tabs/responsive-tabs.scss
  **/
(function ($){
  $.fn.responsiveTabs = function(suffix) {
    //this.addClass('responsive-tabs-' + suffix),
    this.addClass('responsive-tabs-' + suffix),
    this.append($('<span class="dropdown-arrow"></span>')),

    this.on("click", "li > a.active, span.dropdown-arrow", function (){
        this.toggleClass('open');
      }.bind(this)), this.on("click", "li > a:not(.active)", function() {
            this.removeClass("open")
        }.bind(this));
  };

  $("*[data-trigger='responsive-tabs-lg']").responsiveTabs('lg');
  $("*[data-trigger='responsive-tabs-md']").responsiveTabs('md');

})(jQuery);

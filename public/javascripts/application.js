// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

function makeDraggable(ul1) {
	$("#" + ul1 + " li").draggable({stack: "li", revert: "invalid", helper: "clone"});
	$("#dropbox").droppable({
		drop: function(event, ui) {
			// deliver the dropped item at the right box
			var draggableParentId = ui.draggable.parent().attr("id");
			if ((draggableParentId == "available-item-list") || (draggableParentId == "available-service-list")) {
				dest = "#offering-items-offered ul";
			}
			else if (false)  {
				dest = "#wanted-items-offered ul";
			}
			
			// add a 'delete' image
			$li = $("<li></li>").html(ui.draggable.html()).appendTo($(dest));
			$li.addClass(ui.draggable.attr("class")); //.item-li
			$closeIcon = $("<img class='close-icon'/>");
			$closeIcon.attr("src","http://icons.iconarchive.com/icons/visualpharm/must-have/256/Remove-icon.png").appendTo($li);
			
			$closeIcon.click(function() {
				// add back to the available list
				var item = $(this).parent();//li
				console.log(item.attr("class"));
				// add it back to the right place
				var itemClass = item.attr("class");
				var availableUl = "";
				if (itemClass.indexOf("item-li") != -1) {
					availableUl = "available-item-list"; //ul
				}
				else if (itemClass.indexOf("service-li") != -1) {
					availableUl = "available-service-list"; //ul
				}
				item.appendTo($("#" + availableUl));
				makeDraggable(availableUl);
				// remove close icon
				$(this).remove();
			});
			
			ui.draggable.remove();
			ui.helper.remove();
			updateSuggestedValue();
		},
	});
}
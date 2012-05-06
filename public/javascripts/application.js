// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

// FOR OFFER PAGE
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
				putBack(this);
			});
			
			ui.draggable.remove();
			ui.helper.remove();
			updateSuggestedValue();
		},
	});
}

function putBack(t) {
	// add back to the available list
	var item = $(t).parent();//li
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
	$(t).remove();
}


function updateSuggestedValue(div_id) {
	console.log("update value");
	if (typeof div_id === "undefined") div_id = "#suggested-value";
	
	// their total item value
	var their_value = 0;
	$("#offering-items-offered input:hidden[name*='offering']").each(function() {
		their_value += parseFloat(this.value);
	});
	
	// my total item value
	var my_value = 0;
	$("#wanted-items-offered input:hidden[name*='wanted']").each(function() {
		my_value += parseFloat(this.value);
	});
	
				
	// cash
	var cash_offered = parseFloat($("#offer_cash_value_hidden").val());
	// their items worth
	$("#their-value").html("total value: $" + their_value.toFixed(2));
	// my items worth
	$("#my-value").html("total value: $" + my_value.toFixed(2));
	
	var suggested_value = Math.round(parseFloat(my_value) - parseFloat(their_value) - parseFloat(cash_offered)).toFixed(2);
			
	var instruction = "";
	
	if (suggested_value < 0) {
		instruction = "$";
		suggested_value = (-1) * suggested_value;
		$(div_id).css("backgroundColor","royalBlue");
		$(div_id).html(instruction + suggested_value);
		$("#suggested-text").html("You would gain");
					
		$("#cash-value-wrapper .cash-suggested").html(0);
		$("#my-value-wrapper .cash-suggested").html(suggested_value);
	}
	else if (suggested_value > 0){
		instruction = "$";
		$(div_id).css("backgroundColor","darkred");
		$(div_id).html(instruction + suggested_value);
		$("#suggested-text").html("You would lose");
	}
	else {
		instruction = "Fair deal! Let's trade now.";
		$(div_id).css("backgroundColor","orange");
		$(div_id).html(instruction);
	}
}

function updateOfferCashHiddenField(v) {
	v = (((typeof v == "string") && (v.indexOf('$') != -1)) ? v.replace('$','') : v);
	dir = $(".cash-direction option:selected").val();
	v = getCashValueWithCashDirection(dir, v);
	console.log(v);
	$('#offer_cash_value_hidden').val(v);
	updateSuggestedValue();
}

function updateCashDirection(dir) {
	v = $("#offer_cash_value").val();
	v = ((v.indexOf('$') != -1) ? v.replace('$','') : v);
	console.log(dir + ", " + v);
	v = getCashValueWithCashDirection(dir, v);
	updateOfferCashHiddenField(v);
}

function getCashValueWithCashDirection(dir, v) {
	console.log("dir = " + dir);
	if (dir == "i-pay") {
		v = (-1) * parseFloat(v);
	}
	else if (dir == "they-pay") {
		v = parseFloat(v);
	}
	return v;
}
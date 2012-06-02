// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

// FOR OFFER PAGE
function makeDraggable(ul1) {
	$("#" + ul1 + " li").draggable({stack: "li", revert: "invalid", helper: "clone"});
	$("#dropbox").droppable({
		drop: function(event, ui) {
			// deliver the dropped item at the right box
			var draggableParentId = ui.draggable.parent().attr("id");
			if ((draggableParentId == "my-available-item-list") || (draggableParentId == "my-available-service-list")) {
				dest = "#offering-items-offered ul";
			}
			else if ((draggableParentId == "their-available-item-list") || (draggableParentId == "their-available-service-list"))  {
				dest = "#wanted-items-offered ul";
			}
			
			// remove no-item div if exists
			if (dest == "#offering-items-offered ul") {
				$("#no-item-offered").remove();
			}
			else if (dest == "#wanted-items-offered ul") {
				$("#no-item-wanted").remove();
			}
			
			// add a 'delete' image
			$li = $("<li></li>").html(ui.draggable.html()).appendTo($(dest));
			$li.addClass(ui.draggable.attr("class")); //.item-li
			$li.addClass("dropped");
			
			$plus = $("<div></div>");
			// decides whether or not to add a plus sign to the dropped item
			if ($(dest).children().length > 1) {
				$plus.addClass("plus-sign").html("+")
			}
			$plus.appendTo($li);
			
			$closeIcon = $("<img class='close-icon'/>");
			$closeIcon.attr("src","http://icons.iconarchive.com/icons/visualpharm/must-have/256/Remove-icon.png").appendTo($li);
			
			$closeIcon.click(function() {
				putBack(this);
			});
			
			// add a hidden input
			$hidden_input = $("<input>");
			item_id = $li.children(".item-id").html();
			item_price = parseFloat($li.children(".item-price").html().replace("$","").replace(",",""));
			if (dest == "#offering-items-offered ul") {
				$hidden_input.attr("name","offering[" + item_id + "][price]");
			}
			else if (dest == "#wanted-items-offered ul") {
				$hidden_input.attr("name","wanted[" + item_id + "][price]");
			}
			$hidden_input.val(item_price);
			$hidden_input.attr("type","hidden").appendTo($li);
					
			ui.draggable.remove();
			ui.helper.remove();
			updateSuggestedValue();
		},
	});
}

function putBack(t) {
	// add back to the available list
	var item = $(t).parent();//li
	item.removeClass("dropped");
	// remove the plus sign
	item.children(".plus-sign").remove();
	// remove the hidden input
	item.children("input").remove();
	
	if (item.length != 0) {
		// add it back to the right place
		var itemClass = item.attr("class");
		var availableUl = "";
		if (itemClass.indexOf("their-item-li") != -1) {
			availableUl = "their-available-item-list"; //ul
		}
		else if (itemClass.indexOf("their-service-li") != -1) {
			availableUl = "their-available-service-list"; //ul
		}
		else if (itemClass.indexOf("my-item-li") != -1) {
			availableUl = "my-available-item-list"; //ul
		}
		else if (itemClass.indexOf("my-service-li") != -1) {
			availableUl = "my-available-service-list"; //ul
		}
		item.appendTo($("#" + availableUl));
		makeDraggable(availableUl);
	}
	updateSuggestedValue();
	
	// remove close icon
	$(t).remove();
	
	// add the no-item back in place
	// if there is no item
	$their_ul = $("#offering-items-offered ul");
	$my_ul = $("#wanted-items-offered ul");
	// if there is no li in ul and no-item div hasn't been added yet
	if (($their_ul.children("li").length == 0) && ($their_ul.children(".no-item").length == 0)) {
		addNoItemDiv($their_ul);
	} 
	if (($my_ul.children("li").length == 0) && ($my_ul.children(".no-item").length == 0)) {
		addNoItemDiv($my_ul);		
	}
	// removes the plus sign of the first li
	$their_ul.find("li").first().find(".plus-sign").remove();
	$my_ul.find("li").first().find(".plus-sign").remove();
}

function addNoItemDiv(ul) {
	$div = $("<div></div>");
	$div.attr("id","no-item-" + ((ul.parent().attr("id").indexOf("wanted-items-offered") != -1) ? "wanted" : "offered"));
	$div.attr("class","no-item");
	$div.html("No item");
	$div.appendTo($(ul));
}

function updateSuggestedValue(div_id) {
	console.log("update value");
	if (typeof div_id === "undefined") div_id = "#suggested-value";
	
	// their total item value
	var my_value = 0;
	$("#offering-items-offered input:hidden[name*='offering']").each(function() {
		my_value += parseFloat(this.value);
	});
	
	// my total item value
	var their_value = 0;
	$("#wanted-items-offered input:hidden[name*='wanted']").each(function() {
		their_value += parseFloat(this.value);
	});
	
				
	// cash
	var cash_offered = parseFloat($("#offer_cash_value_hidden").val());
	// their items worth
	$("#their-value .cash-value").html("$" + their_value.toFixed(2));
	// my items worth
	$("#my-value .cash-value").html("$" + my_value.toFixed(2));
	// diff
	console.log(my_value.toFixed(2) + ", " + their_value.toFixed(2) + ", " + cash_offered);
	var diff = my_value.toFixed(2) - their_value.toFixed(2);// - cash_offered;
	var diff_sign = (diff<0)?"+":"-";
	diff = Math.abs(diff).toFixed(2);
	$("#diff .cash-value").html(diff_sign + " $" + diff);
	
	//var suggested_value = Math.round(parseFloat(my_value) - parseFloat(their_value) - parseFloat(cash_offered)).toFixed(2);
	// SET theypay ipay value
	var suggested_value = diff;	
	if (diff_sign == "-") {
		$(".cash-compensate label").html("They pay");
	} else {
		$(".cash-compensate label").html("Bargain");
	}
	// set hidden field
	$("#offer_cash_value_hidden").val(diff_sign + diff);
	// if text box changed, update hidden field
	$("#offer_cash_value").val(diff).change(function() {
		$("#offer_cash_value_hidden").val(diff_sign + $(this).val());
	});

	//
	var instruction = "";
	
	if (suggested_value < 0) {
		instruction = "$";
		suggested_value = (-1) * suggested_value;
		$(div_id).html(instruction + suggested_value);
		$("#suggested-text").html("You pay: ");
					
		$("#cash-value-wrapper .cash-suggested").html(0);
		$("#my-value-wrapper .cash-suggested").html(suggested_value);
	}
	else if (suggested_value > 0){
		instruction = "$";
		//$(div_id).css("backgroundColor","darkred");
		$(div_id).html(instruction + suggested_value);
		$("#suggested-text").html("They pay: ");
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
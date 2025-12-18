// Disable chosing individual objects when a scrip is applied globally
htmx.onLoad(function(elt) {
    var global_checkboxes = [
        "form[name=AddRemoveScrip] input[type=checkbox][name^=AddScrip-][value=0]",
        "form input[type=checkbox][name^=AddCustomField-][value=0]"
    ];
    jQuery(elt).find(global_checkboxes.join(", "))
        .change(function(){
            var self    = jQuery(this);
            var checked = self.prop("checked");

            self.closest("form")
                .find("table.collection input[type=checkbox]")
                .prop("disabled", checked);
        });
});

// Replace user references in history with the HTML versions
function ReplaceUserReferences(elt) {
    var users = jQuery(elt).find(".user[data-replace=user]");
    var ids   = jQuery.unique(users.map(function(){
        return "id=" + encodeURIComponent(jQuery(this).attr("data-user-id"))
    }).toArray().sort()).join(";"); // Sort to put same items together so jQuery.unique can remove them.

    if (!ids.length)
        return

    jQuery.get(
        RT.Config.WebPath + "/Helpers/UserInfo?" + ids,
        function(json) {
            users.each(function() {
                var user = jQuery(this);
                var uid  = user.attr("data-user-id");
                if (!json[uid])
                    return
                user.removeAttr("data-replace")
                    .html( jQuery(json[uid]._html).html() );
            });
        }
    );
}
htmx.onLoad(ReplaceUserReferences);

// Cascaded selects
htmx.onLoad(function(elt) {
    jQuery(elt).find("select.cascade-by-optgroup").each(function(){
        var name = this.name;
        if (!name) return;

        // Generate elements for cascading based on the master <select> ...
        var complete = jQuery(this)
            .clone(true, true)
            .attr("name", name + "-Complete")
            .attr("disabled", "disabled")
            .addClass('hidden')
            .insertAfter(this);

        const groups_div = jQuery(this).closest('div')
            .clone(true, true).insertBefore(this.closest('div'));
        const groups = groups_div.find('select')
            .attr("name", name + "-Groups")
            .find("option").remove().end()
            .find("optgroup").replaceWith(function(){
                return jQuery("<option>").val(this.label).text(this.label);
            }).end()
            .prepend( complete.find("option[value='']") )
            .addClass('selectpicker');

        // Synchronize the <select> we just generated
        var selected = jQuery("option[selected]", this).parent().attr("label");
        if (selected === undefined) selected = "";
        jQuery('option[value="' + selected + '"]', groups).attr("selected", "selected");

        this.classList.add('selectpicker');

        // Wire it all up
        groups.change(function(){
            var name     = this.name.replace(/-Groups$/, '');
            var field    = jQuery(this);
            var subfield = field.closest('.rt-value').find("select[name=" + name + "]");
            var complete = field.closest('.rt-value').find("select[name=" + name + "-Complete]");
            var value    = field.val();
            filter_cascade_select( subfield[0], complete[0], value );
        }).change();
        initializeSelectElements(this.closest('.rt-value'));
    });

    jQuery(elt).find('[data-cascade-based-on-name]').each( function() {
        var based_on_name = jQuery(this).attr('data-cascade-based-on-name');
        var based_on = jQuery('[name^="' + based_on_name + '"][type!="hidden"]:input:not(.hidden)');
        var id = jQuery(this).attr('id');
        based_on.each( function() {
            var oldchange = jQuery(this).onchange;
            jQuery(this).change( function () {
                var vals;
                if ( jQuery(this).is('select') ) {
                    vals = based_on.first().val();
                }
                else {
                    vals = [];
                    jQuery(based_on).each( function() {
                        if ( jQuery(this).is(':checked') ) {
                            vals.push(jQuery(this).val());
                        }
                    });
                }
                filter_cascade_by_id( id, vals );
                if (oldchange != null)
                    oldchange();
            });
        });

        if ( based_on.is('select') ) {
            based_on.change();
        }
        else {
            based_on.first().change();
        }
    });
});

htmx.onLoad( function(elt) {
    jQuery(elt).find("input[type=file]").change( function() {
        var input = jQuery(this);
        var warning = input.next(".invalid");

        if ( !input.val().match(/"/) ) {
            warning.hide();
        } else {
            if (warning.length) {
                warning.show();
            } else {
                input.val("");
                jQuery("<span class='invalid'>")
                    .text(loc_key("quote_in_filename"))
                    .insertAfter(input);
            }
        }
    });
});

htmx.onLoad(function(elt) {
    jQuery(elt).find("#UpdateType").change(function(ev) {
        jQuery(".messagebox-container")
            .removeClass("action-response action-private")
            .addClass("action-"+ev.target.value);
    });
});

htmx.onLoad(function(elt) {
    jQuery(elt).find('.toggle-txn-details:not(.toggle-txn-details-registered)').click(function () {
        return toggleTransactionDetails.apply(this);
    }).addClass('toggle-txn-details-registered');
});

const article_link_focus_handler = function() {
  // if input focus in last row add another row of inputs
  const link_div  = jQuery(this).parent().parent();
  const links_div = link_div.parent();
  if ( link_div.attr('data-link-number') == links_div.attr('data-link-count') ) {
    const link_count = parseInt( links_div.attr('data-link-count') ) + 1;
    links_div.attr( 'data-link-count', link_count );
    let new_link_div = link_div.clone();
    new_link_div.attr( 'data-link-number', link_count );
    new_link_div.find('[name^="article-link-"]').each(function(){
      var oldName = jQuery(this).attr('name');
      var newName = oldName.replace( /-\d+$/, '-' + link_count );
      jQuery(this).attr( 'name', newName );
    });
    new_link_div.find('[name^="article-link-"]').on( "focus", article_link_focus_handler );
    links_div.append(new_link_div);
  }
};
htmx.onLoad(function(elt) {
    jQuery('[name^="article-link-"]').on( "focus", article_link_focus_handler );
});
htmx.onLoad(function(elt) {
    jQuery(elt).find('.article-basics [name="Type"]').change(function(ev) {
        if ( jQuery(this).val() == 'Content' ) {
            jQuery('#article-type-links').addClass('hidden');
            jQuery('#article-type-content').removeClass('hidden');
        }
        else {
            jQuery('#article-type-content').addClass('hidden');
            jQuery('#article-type-links').removeClass('hidden');
        }
    });
});

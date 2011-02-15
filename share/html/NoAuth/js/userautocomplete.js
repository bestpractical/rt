%# BEGIN BPS TAGGED BLOCK {{{
%#
%# COPYRIGHT:
%#
%# This software is Copyright (c) 1996-2011 Best Practical Solutions, LLC
%#                                          <sales@bestpractical.com>
%#
%# (Except where explicitly superseded by other copyright notices)
%#
%#
%# LICENSE:
%#
%# This work is made available to you under the terms of Version 2 of
%# the GNU General Public License. A copy of that license should have
%# been provided with this software, but in any event can be snarfed
%# from www.gnu.org.
%#
%# This work is distributed in the hope that it will be useful, but
%# WITHOUT ANY WARRANTY; without even the implied warranty of
%# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
%# General Public License for more details.
%#
%# You should have received a copy of the GNU General Public License
%# along with this program; if not, write to the Free Software
%# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
%# 02110-1301 or visit their web page on the internet at
%# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
%#
%#
%# CONTRIBUTION SUBMISSION POLICY:
%#
%# (The following paragraph is not intended to limit the rights granted
%# to you to modify and distribute this software under the terms of
%# the GNU General Public License and is only of importance to you if
%# you choose to contribute your changes and enhancements to the
%# community by submitting them to Best Practical Solutions, LLC.)
%#
%# By intentionally submitting any modifications, corrections or
%# derivatives to this work, or any other work intended for use with
%# Request Tracker, to Best Practical Solutions, LLC, you confirm that
%# you are the copyright holder for those contributions and you grant
%# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
%# royalty-free, perpetual, license to use, copy, create derivative
%# works based on those contributions, and sublicense and distribute
%# those contributions and any derivatives thereof.
%#
%# END BPS TAGGED BLOCK }}}
jQuery(function() {
    // inputs that accept multiple email addresses
    var multipleCompletion = new Array("Requestors", "To", "Bcc", "Cc", "AdminCc", "WatcherAddressEmail[123]", "UpdateCc", "UpdateBcc");

    // inputs with only a single email address allowed
    var singleCompletion   = new Array("(Add|Delete)Requestor", "(Add|Delete)Cc", "(Add|Delete)AdminCc");

    // inputs for only privileged users
    var privilegedCompletion = new Array("AddPrincipalForRights-user");

    // build up the regexps we'll use to match
    var applyto  = new RegExp('^(' + multipleCompletion.concat(singleCompletion, privilegedCompletion).join('|') + ')$');
    var acceptsMultiple = new RegExp('^(' + multipleCompletion.join('|') + ')$');
    var onlyPrivileged = new RegExp('^(' + privilegedCompletion.join('|') + ')$');

    var inputs = document.getElementsByTagName("input");

    for (var i = 0; i < inputs.length; i++) {
        var input = inputs[i];
        var inputName = input.getAttribute("name");

        if (!inputName || !inputName.match(applyto))
            continue;

        var options = {
            source: "<% RT->Config->Get('WebPath')%>/Helpers/Autocomplete/Users"
        };

        var queryargs = [];

        if (inputName.match("AddPrincipalForRights-user")) {
            queryargs.push("return=Name");
            options.select = addprincipal_onselect;
            options.change = addprincipal_onchange;
        }

        if (inputName.match(onlyPrivileged)) {
            queryargs.push("privileged=1");
        }

        if (inputName.match(acceptsMultiple)) {
            queryargs.push("delim=,");

            options.focus = function () {
                // prevent value inserted on focus
                return false;
            }

            options.select = function(event, ui) {
                var terms = this.value.split(/,\s*/);
                terms.pop();                    // remove current input
                terms.push( ui.item.value );    // add selected item
                this.value = terms.join(", ");
                return false;
            }
        }

        if (queryargs.length)
            options.source += "?" + queryargs.join("&");

        jQuery(input).autocomplete(options);
    }
});

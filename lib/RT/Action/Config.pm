use strict;
use warnings;

=head1 NAME

RT::Action::Config

=cut

package RT::Action::Config;
use base qw/RT::Action Jifty::Action/;

use Jifty::Param::Schema;
use Jifty::Action schema {
    param 'active_make_clicky' =>
        label is 'active_make_clicky';
    param 'active_status' =>
        label is 'active_status';
    param 'ambiguous_day_in_future' =>
        label is 'ambiguous_day_in_future';
    param 'ambiguous_day_in_past' =>
        label is 'ambiguous_day_in_past';
    param 'auto_create' =>
        label is 'auto_create';
    param 'auto_logoff' =>
        label is 'auto_logoff';
    param 'canonicalize_email_match'     =>
        label is 'canonicalize_email_match';
    param 'canonicalize_email_replace' =>
        label is 'canonicalize_email_replace';
    param 'canonicalize_on_create' =>
        label is 'canonicalize_on_create';
    param 'canonicalize_redirect_urls' =>
        label is 'canonicalize_redirect_urls';
    param 'chart_font' =>
        label is 'chart_font';
    param 'comment_address' =>
        label is 'comment_address';
    param 'correspond_address' =>
        label is 'correspond_address';
    param 'custom_field_values_sources' =>
        label is 'custom_field_values_sources';
    param 'dashboard_address' =>
        label is 'dashboard_address';
    param 'dashboard_subject' =>
        label is 'dashboard_subject';
    param 'date_day_before_month' =>
        label is 'date_day_before_month';
    param 'date_time_format' =>
        label is 'date_time_format';
    param 'default_queue' =>
        label is 'default_queue';
    param 'default_search_result_format' =>
        label is 'default_search_result_format';
    param 'default_summary_rows' =>
        label is 'default_summary_rows';
    param 'dont_search_file_attachments' =>
        label is 'dont_search_file_attachments';
    param 'drop_long_attachments' =>
        label is 'drop_long_attachments';
    param 'email_input_encodings' =>
        label is 'email_input_encodings';
    param 'email_output_encoding' =>
        label is 'email_output_encoding';
    param 'email_subject_tag_regex' =>
        label is 'email_subject_tag_regex';
    param 'enable_reminders' =>
        label is 'enable_reminders';
    param 'extract_subject_tag_match' =>
        label is 'extract_subject_tag_match';
    param 'forward_from_user' =>
        label is 'forward_from_user';
    param 'friendly_from_line_format' =>
        label is 'friendly_from_line_format';
    param 'friendly_to_line_format' =>
        label is 'friendly_to_line_format';
    param 'gnupg' =>
        label is 'gnupg';
    param 'gnupg_options' =>
        label is 'gnupg_options';
    param 'homepage_components' =>
        label is 'homepage_components';
    param 'inactive_status' =>
        label is 'inactive_status';
    param 'lexicon_languages' =>
        label is 'lexicon_languages';
    param 'link_transactions_run1_scrip' =>
        label is 'link_transactions_run1_scrip';
    param 'log_dir' =>
        label is 'log_dir';
    param 'log_stack_traces' =>
        label is 'log_stack_traces';
    param 'log_to_file' =>
        label is 'log_to_file';
    param 'log_to_file_named' =>
        label is 'log_to_file_named';
    param 'log_to_screen' =>
        label is 'log_to_screen';
    param 'log_to_syslog' =>
        label is 'log_to_syslog';
    param 'log_to_syslog_conf' =>
        label is 'log_to_syslog_conf';
    param 'logo_url' =>
        label is 'logo_url';
    param 'loops_to_rt_owner' =>
        label is 'loops_to_rt_owner';
    param 'mail_command' =>
        label is 'mail_command';
    param 'mail_params' =>
        label is 'mail_params';
    param 'mail_plugins' =>
        label is 'mail_plugins';
    param 'mason_parameters' =>
        label is 'mason_parameters';
    param 'max_attachment_size' =>
        label is 'max_attachment_size';
    param 'max_inline_body' =>
        label is 'max_inline_body';
    param 'message_box_height' =>
        label is 'message_box_height';
    param 'message_box_include_signature' =>
        label is 'message_box_include_signature';
    param 'message_box_rich_text' =>
        label is 'message_box_rich_text';
    param 'message_box_rich_text_height' =>
        label is 'message_box_rich_text_height';
    param 'message_box_width' =>
        label is 'message_box_width';
    param 'message_box_wrap' =>
        label is 'message_box_wrap';
    param 'minimum_password_length' =>
        label is 'minimum_password_length';
    param 'net_server_options' =>
        label is 'net_server_options';
    param 'notify_actor' =>
        label is 'notify_actor';
    param 'oldest_transactions_first' =>
        label is 'oldest_transactions_first';
    param 'organization' =>
        label is 'organization';
    param 'owner_email' =>
        label is 'owner_email';
    param 'parse_new_message_for_ticket_ccs' =>
        label is 'parse_new_message_for_ticket_ccs';
    param 'plain_text_pre' =>
        label is 'plain_text_pre';
    param 'prefer_rich_text' =>
        label is 'prefer_rich_text';
    param 'preview_scrip_messages' =>
        label is 'preview_scrip_messages';
    param 'record_outgoing_email' =>
        label is 'record_outgoing_email';
    param 'redistribute_auto_generated_messages' =>
        label is 'redistribute_auto_generated_messages';
    param 'rt_address_regexp' =>
        label is 'rt_address_regexp';
    param 'rtname' =>
        label is 'rtname';
    param 'self_service_regex' =>
        label is 'self_service_regex';
    param 'sender_must_exist_in_external_database' =>
        label is 'sender_must_exist_in_external_database';
    param 'sendmail_arguments' =>
        label is 'sendmail_arguments';
    param 'sendmail_bounce_arguments' =>
        label is 'sendmail_bounce_arguments';
    param 'sendmail_path' =>
        label is 'sendmail_path';
    param 'show_bcc_header' =>
        label is 'show_bcc_header';
    param 'show_transaction_images' =>
        label is 'show_transaction_images';
    param 'show_unread_message_notifications' =>
        label is 'show_unread_message_notifications';
    param 'smtp_debug' =>
        label is 'smtp_debug';
    param 'smtp_from' =>
        label is 'smtp_from';
    param 'smtp_server' =>
        label is 'smtp_server';
    param 'standalone_max_requests' =>
        label is 'standalone_max_requests';
    param 'standalone_max_servers' =>
        label is 'standalone_max_servers';
    param 'standalone_max_spare_servers' =>
        label is 'standalone_max_spare_servers';
    param 'standalone_min_servers' =>
        label is 'standalone_min_servers';
    param 'standalone_min_spare_servers' =>
        label is 'standalone_min_spare_servers';
    param 'statement_log' =>
        label is 'statement_log';
    param 'store_loops' =>
        label is 'store_loops';
    param 'strict_link_acl' =>
        label is 'strict_link_acl';
    param 'suppress_inline_text_files' =>
        label is 'suppress_inline_text_files';
    param 'time_zone' =>
        label is 'time_zone';
    param 'truncate_long_attachments' =>
        label is 'truncate_long_attachments';
    param 'trust_html_attachments' =>
        label is 'trust_html_attachments';
    param 'use_friendly_from_line' =>
        label is 'use_friendly_from_line';
    param 'use_friendly_to_line' =>
        label is 'use_friendly_to_line';
    param 'use_sql_for_acl_checks' =>
        label is 'use_sql_for_acl_checks';
    param 'use_transaction_batch' =>
        label is 'use_transaction_batch';
    param 'username_format' =>
        label is 'username_format';
    param 'web_base_url' =>
        label is 'web_base_url';
    param 'web_default_stylesheet' =>
        label is 'web_default_stylesheet';
    param 'web_domain' =>
        label is 'web_domain';
    param 'web_external_auth' =>
        label is 'web_external_auth';
    param 'web_external_auto' =>
        label is 'web_external_auto';
    param 'web_external_gecos' =>
        label is 'web_external_gecos';
    param 'web_fallback_to_internal_auth' =>
        label is 'web_fallback_to_internal_auth';
    param 'web_flush_db_cache_every_request' =>
        label is 'web_flush_db_cache_every_request';
    param 'web_images_url' =>
        label is 'web_images_url';
    param 'web_no_auth_regex' =>
        label is 'web_no_auth_regex';
    param 'web_path' =>
        label is 'web_path';
    param 'web_port' =>
        label is 'web_port';
    param 'web_secure_cookies' =>
        label is 'web_secure_cookies';
    param 'web_url' =>
        label is 'web_url';
    param 'wiki_implicit_links' =>
        label is 'wiki_implicit_links';
};

=head2 take_action

=cut

sub take_action {
    my $self = shift;

    $self->report_success if not $self->result->failure;
    return 1;
}

=head2 report_success

=cut

sub report_success {
    my $self = shift;

    # Your success message here
    $self->result->message('Success');
}

1;


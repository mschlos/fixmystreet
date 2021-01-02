package FixMyStreet::Cobrand::CentralBedfordshire;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

sub council_area_id { 21070 }
sub council_area { 'Central Bedfordshire' }
sub council_name { 'Central Bedfordshire Council' }
sub council_url { 'centralbedfordshire' }
sub send_questionnaires { 0 }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    my $town = "Bedfordshire";

    return {
        %{ $self->SUPER::disambiguate_location() },
        town => $town,
        centre => '52.006697,-0.436005',
        bounds => [ 51.805087, -0.702181, 52.190913, -0.143957 ],
    };
}

sub enter_postcode_text { 'Enter a postcode, street name and area, or check an existing report number' }

sub open311_munge_update_params {
    my ($self, $params, $comment, $body) = @_;

    # TODO: This is the same as Bexley - could be factored into its own Role.
    $params->{service_request_id_ext} = $comment->problem->id;

    my $contact = $comment->problem->contact;
    $params->{service_code} = $contact->email;
}

sub open311_extra_data_include {
    my ($self, $row, $h, $extra, $contact) = @_;

    my $cfg = $self->feature('area_code_mapping') || return;
    my @areas = split ',', $row->areas;
    my @matches = grep { $_ } map { $cfg->{$_} } @areas;
    if (@matches) {
        return [
            { name => 'area_code', value => $matches[0] },
        ];
    }
}

sub open311_post_send {
    my ($self, $row, $h) = @_;

    # Check Open311 was successful
    return unless $row->external_id;

    # For certain categories, send an email also
    my $emails = $self->feature('open311_email');
    my $dest = $emails->{$row->category};
    return unless $dest;

    my $sender = FixMyStreet::SendReport::Email->new( to => [ [ $dest, "Central Bedfordshire" ] ] );
    $sender->send($row, $h);
}


sub report_sent_confirmation_email { 'external_id' }

# Don't show any reports made before the go-live date at all.
sub cut_off_date { '2020-12-02' }

1;

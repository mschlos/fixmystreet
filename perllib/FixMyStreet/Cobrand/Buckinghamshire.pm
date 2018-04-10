package FixMyStreet::Cobrand::Buckinghamshire;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

use LWP::Simple;
use URI;
use Try::Tiny;
use JSON::MaybeXS;

sub council_area_id { return 2217; }
sub council_area { return 'Buckinghamshire'; }
sub council_name { return 'Buckinghamshire County Council'; }
sub council_url { return 'buckinghamshire'; }

sub example_places {
    return ( 'HP19 7QF', "Walton Road" );
}

sub base_url {
    my $self = shift;
    return $self->next::method() if FixMyStreet->config('STAGING_SITE');
    return 'https://fixmystreet.buckscc.gov.uk';
}

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    my $town = 'Buckinghamshire';

    # The geocoder returns two results for 'Aylesbury', so force the better
    # result to be used.
    $town = "$town, HP20 2NH" if $string =~ /[\s]*aylesbury[\s]*/i;

    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => $town,
        centre => '51.7852948471218,-0.812140044990842',
        span   => '0.596065946222112,0.664092167105497',
        bounds => [ 51.4854160129405, -1.1406945585036, 52.0814819591626, -0.476602391398098 ],
    };
}

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'grey' if $p->state eq 'not responsible';
    return 'green' if $p->is_fixed || $p->is_closed;
    return 'red' if $p->state eq 'confirmed';
    return 'yellow';
}

sub contact_email {
    my $self = shift;
    return join( '@', 'fixmystreetbs', 'buckscc.gov.uk' );
}

sub send_questionnaires {
    return 0;
}

sub open311_config {
    my ($self, $row, $h, $params) = @_;

    my $extra = $row->get_extra_fields;
    push @$extra,
        { name => 'report_url',
          value => $h->{url} },
        { name => 'title',
          value => $row->title },
        { name => 'description',
          value => $row->detail };

    # Reports made via FMS.com or the app probably won't have a site code
    # value because we don't display the adopted highways layer on those
    # frontends. Instead we'll look up the closest asset from the WFS
    # service at the point we're sending the report over Open311.
    if (!$row->get_extra_field_value('site_code')) {
        if (my $site_code = $self->lookup_site_code($row)) {
            push @$extra,
                { name => 'site_code',
                value => $site_code };
        }
    }

    $row->set_extra_fields(@$extra);
}

sub map_type { 'Buckinghamshire' }

sub default_map_zoom { 3 }

sub enable_category_groups { 1 }

# Enable adding/editing of parish councils in the admin
sub add_extra_areas {
    my ($self, $areas) = @_;

    # This is a list of all Parish Councils within Buckinghamshire,
    # taken from https://mapit.mysociety.org/area/2217/covers.json?type=CPC
    my $parish_ids = [
        "135493",
        "135494",
        "148713",
        "148714",
        "53319",
        "53360",
        "53390",
        "53404",
        "53453",
        "53486",
        "53515",
        "53542",
        "53612",
        "53822",
        "53874",
        "53887",
        "53942",
        "53991",
        "54003",
        "54014",
        "54158",
        "54174",
        "54178",
        "54207",
        "54289",
        "54305",
        "54342",
        "54355",
        "54402",
        "54465",
        "54479",
        "54493",
        "54590",
        "54615",
        "54672",
        "54691",
        "54721",
        "54731",
        "54787",
        "54846",
        "54879",
        "54971",
        "55290",
        "55326",
        "55534",
        "55638",
        "55724",
        "55775",
        "55896",
        "55900",
        "55915",
        "55945",
        "55973",
        "56007",
        "56091",
        "56154",
        "56268",
        "56350",
        "56379",
        "56418",
        "56432",
        "56498",
        "56524",
        "56592",
        "56609",
        "56641",
        "56659",
        "56664",
        "56709",
        "56758",
        "56781",
        "57099",
        "57138",
        "57330",
        "57332",
        "57366",
        "57367",
        "57507",
        "57529",
        "57582",
        "57585",
        "57666",
        "57701",
        "58166",
        "58208",
        "58229",
        "58279",
        "58312",
        "58333",
        "58405",
        "58523",
        "58659",
        "58815",
        "58844",
        "58891",
        "58965",
        "58980",
        "59003",
        "59007",
        "59012",
        "59067",
        "59144",
        "59152",
        "59179",
        "59211",
        "59235",
        "59288",
        "59353",
        "59491",
        "59518",
        "59727",
        "59763",
        "59971",
        "60027",
        "60137",
        "60321",
        "60322",
        "60438",
        "60456",
        "60462",
        "60532",
        "60549",
        "60598",
        "60622",
        "60640",
        "60731",
        "60777",
        "60806",
        "60860",
        "60954",
        "61100",
        "61102",
        "61107",
        "61142",
        "61144",
        "61167",
        "61172",
        "61249",
        "61268",
        "61269",
        "61405",
        "61445",
        "61471",
        "61479",
        "61898",
        "61902",
        "61920",
        "61964",
        "62226",
        "62267",
        "62296",
        "62311",
        "62321",
        "62431",
        "62454",
        "62640",
        "62657",
        "62938",
        "63040",
        "63053",
        "63068",
        "63470",
        "63476",
        "63501",
        "63507",
        "63517",
        "63554",
        "63715",
        "63723"
    ];
    my $ids_string = join ",", @{ $parish_ids };

    my $extra_areas = mySociety::MaPit::call('areas', [ $ids_string ]);

    my %all_areas = (
        %$areas,
        %$extra_areas
    );
    return \%all_areas;
}

# Make sure CPC areas are included in point lookups for new reports
sub add_extra_area_types {
    my ($self, $types) = @_;

    my @types = (
        @$types,
        'CPC',
    );
    return \@types;
}

sub is_two_tier { 1 }

sub should_skip_sending_update {
    my ($self, $update ) = @_;

    # Bucks don't want to receive updates into Confirm that were made by anyone
    # except the original problem reporter.
    return $update->user_id != $update->problem->user_id;
}

sub disable_phone_number_entry { 1 }

sub report_sent_confirmation_email { 1 }

sub is_council_with_case_management { 1 }

# Try OSM for Bucks as it provides better disamiguation descriptions.
sub get_geocoder { 'OSM' }

sub categories_restriction {
    my ($self, $rs) = @_;
    # Buckinghamshire is a two-tier council, but only want to display
    # county-level categories on their cobrand.
    return $rs->search( { 'body.id' => 2217 } );
}

sub lookup_site_code {
    my $self = shift;
    my $row = shift;

    my $buffer = 5; # metres
    my ($x, $y) = $row->local_coords;
    my ($w, $s, $e, $n) = ($x-$buffer, $y-$buffer, $x+$buffer, $y+$buffer);

    my $uri = URI->new("https://tilma.staging.mysociety.org/mapserver/bucks");
    $uri->query_form(
        REQUEST => "GetFeature",
        SERVICE => "WFS",
        SRSNAME => "urn:ogc:def:crs:EPSG::27700",
        TYPENAME => "Whole_Street",
        VERSION => "1.1.0",
        outputformat => "geojson",
        BBOX => "$w,$s,$e,$n"
    );

    my $response = get($uri);

    my $j = JSON->new->utf8->allow_nonref;
    try {
        $j = $j->decode($response);
        return $j->{features}->[0]->{properties}->{site_code};
    } catch {
        # There was either no asset found, or an error with the WFS
        # call - in either case let's just proceed without the USRN.
        return;
    }

}

1;
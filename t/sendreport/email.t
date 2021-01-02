use FixMyStreet;
use FixMyStreet::DB;
use FixMyStreet::SendReport::Email;
use FixMyStreet::TestMech;

ok( my $mech = FixMyStreet::TestMech->new, 'Created mech object' );

my $e = FixMyStreet::SendReport::Email->new();

# area id 1000
my $params = { id => 1000, name => 'Council of the Thousand' };
my $body = FixMyStreet::DB->resultset('Body')->find_or_create($params);
ok $body, "found/created body";

my $contact = $mech->create_contact_ok(
    email => 'council@example.com',
    body_id => 1000,
    category => 'category',
    note => '',
);

my $row = FixMyStreet::DB->resultset('Problem')->new( {
    id => 123,
    user => FixMyStreet::DB->resultset('User')->new({
        email => 'test@example.net',
        email_verified => 1,
    }),
    bodies_str => '1000',
    category => 'category',
    cobrand => '',
} );

ok $e;

foreach my $test ( {
        desc => 'no councils added means no receipients',
        count => 0,
        add_council => 0,
    },
    {
        desc => 'adding a council results in receipients',
        count => 1,
        add_council => 1,
    },
    {
        desc => 'unconfirmed contact results in no receipients',
        count => 0,
        add_council => 1,
        unconfirmed => 1,
        expected_note => 'Body 1000 deleted',
    },
    {
        desc => 'unconfirmed contact note uses note from contact table',
        count => 0,
        add_council => 1,
        unconfirmed => 1,
        note => 'received bounced so unconfirmed',
        expected_note => 'received bounced so unconfirmed',
    },
) {
    subtest $test->{desc} => sub {
        my $e = FixMyStreet::SendReport::Email->new;
        $contact->update( { state => 'unconfirmed' } ) if $test->{unconfirmed};
        $contact->update( { note => $test->{note} } ) if $test->{note};
        $e->add_body( $body ) if $test->{add_council};
        is $e->build_recipient_list( $row, {} ), $test->{count}, 'correct recipient list count';

        if ( $test->{unconfirmed} ) {
            is_deeply $e->unconfirmed_data, { 'council@example.com' => {
                'category' => { 'count' => 1, 'note' => $test->{expected_note} }
            } }, 'correct unconfirmed_data';
        }
    };
}

subtest 'check use_verp' => sub {
        my $e = FixMyStreet::SendReport::Email->new( use_verp => 0 );
        is $e->envelope_sender($row), 'do-not-reply@example.org';
        $e = FixMyStreet::SendReport::Email->new( use_verp => 1 );
        like $e->envelope_sender($row), qr/fms-report-123-[0-9a-f]+\@example.org/;
};

done_testing();

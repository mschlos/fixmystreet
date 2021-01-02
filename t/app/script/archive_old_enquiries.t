use FixMyStreet::TestMech;
use FixMyStreet::Script::ArchiveOldEnquiries;

use File::Temp;
use Path::Tiny;
use Test::Exception;

my $mech = FixMyStreet::TestMech->new();

$mech->clear_emails_ok;

my $user = $mech->create_user_ok('test@example.com', name => 'Test User');
my $oxfordshire = $mech->create_body_ok(2237, 'Oxfordshire County Council');
my $west_oxon = $mech->create_body_ok(2420, 'West Oxfordshire District Council');

my $opts = {
    commit => 1,
    body => $oxfordshire->id,
    cobrand => 'oxfordshire',
    closure_cutoff => "2015-01-01 00:00:00",
    email_cutoff => "2016-01-01 00:00:00",
    user => $user->id,
};

subtest 'sets reports to the correct status' => sub {
    FixMyStreet::override_config {
          ALLOWED_COBRANDS => [ 'oxfordshire' ],
    }, sub {
        my ($report) = $mech->create_problems_for_body(1, $oxfordshire->id, 'Test', {
            areas      => ',2237,',
            user_id    => $user->id,
        });

        my ($report1) = $mech->create_problems_for_body(1, $oxfordshire->id . "," .$west_oxon->id, 'Test', {
            areas      => ',2237,',
            lastupdate => '2015-12-01 07:00:00',
            user       => $user,
        });

        my ($report2) = $mech->create_problems_for_body(1, $oxfordshire->id, 'Test 2', {
            areas      => ',2237,',
            lastupdate => '2015-12-01 08:00:00',
            user       => $user,
            state      => 'investigating',
        });

        my ($report3, $report4) = $mech->create_problems_for_body(2, $oxfordshire->id, 'Test', {
            areas      => ',2237,',
            lastupdate => '2014-12-01 07:00:00',
            user       => $user,
        });

        my ($report5) = $mech->create_problems_for_body(1, $oxfordshire->id . "," .$west_oxon->id, 'Test', {
            areas      => ',2237,',
            lastupdate => '2014-12-01 07:00:00',
            user       => $user,
            state      => 'in progress'
        });

        FixMyStreet::Script::ArchiveOldEnquiries::archive($opts);

        $report->discard_changes;
        $report1->discard_changes;
        $report2->discard_changes;
        $report3->discard_changes;
        $report4->discard_changes;
        $report5->discard_changes;

        is $report1->state, 'closed', 'Report 1 has been set to closed';
        is $report2->state, 'closed', 'Report 2 has been set to closed';
        is $report3->state, 'closed', 'Report 3 has been set to closed';
        is $report4->state, 'closed', 'Report 4 has been set to closed';
        is $report5->state, 'closed', 'Report 5 has been set to closed';

        my $comment = $report1->comments->first;
        is $comment->problem_state, 'closed';

        is $report->state, 'confirmed', 'Recent report has been left alone';
    };
};

subtest 'marks alerts as sent' => sub {
    FixMyStreet::override_config {
          ALLOWED_COBRANDS => [ 'oxfordshire' ],
    }, sub {
        my ($report) = $mech->create_problems_for_body(1, $oxfordshire->id, 'Test', {
            areas      => ',2237,',
            lastupdate => '2015-12-01 07:00:00',
            user_id    => $user->id,
        });
        my $alert = FixMyStreet::DB->resultset('Alert')->find_or_create(
            {
                user => $user,
                parameter => $report->id,
                alert_type => 'new_updates',
                whensubscribed => '2015-12-01 07:00:00',
                confirmed => 1,
                cobrand => 'default',
            }
        );
        is $alert->alerts_sent->count, 0, 'Nothing has been sent for this alert';

        FixMyStreet::Script::ArchiveOldEnquiries::archive($opts);

        $report->discard_changes;

        is $report->state, 'closed', 'Report has been set to closed';

        is $alert->alerts_sent->count, 1, 'Alert marked as sent for this report';

        my $alert_sent = $alert->alerts_sent->first;
        my $comment = $report->comments->first;
        is $alert_sent->parameter, $comment->id, 'AlertSent created for new comment';
    };
};

subtest 'sends emails to a user' => sub {
    FixMyStreet::override_config {
      ALLOWED_COBRANDS => [ 'oxfordshire' ],
    }, sub {
        $mech->clear_emails_ok;
        $mech->email_count_is(0);

        $mech->create_problems_for_body(1, $oxfordshire->id, 'Shiny new report', {
            areas      => ',2237,',
            user       => $user,
        });

        $mech->create_problems_for_body(1, $oxfordshire->id, 'Problem the first', {
            areas      => ',2237,',
            lastupdate => '2015-12-01 07:00:00',
            user       => $user,
        });

        $mech->create_problems_for_body(1, $oxfordshire->id, 'Problem the second', {
            areas      => ',2237,',
            lastupdate => '2015-12-01 07:00:00',
            user       => $user,
        });

        $mech->create_problems_for_body(1, $oxfordshire->id, 'Problem the third', {
            areas      => ',2237,',
            lastupdate => '2015-12-01 07:00:00',
            user       => $user,
        });

        $mech->create_problems_for_body(1, $oxfordshire->id, 'Really old report', {
            areas      => ',2237,',
            lastupdate => '2014-12-01 07:00:00',
            user       => $user,
        });

        FixMyStreet::Script::ArchiveOldEnquiries::archive($opts);

        my @emails = $mech->get_email;
        $mech->email_count_is(1);

        my $email = $emails[0];
        my $body = $mech->get_text_body_from_email($email);

        like $body, qr/Problem the first/, 'Email body matches report name';
        like $body, qr/Problem the second/, 'Email body matches report name';
        like $body, qr/Problem the third/, 'Email body matches report name';

        unlike  $body, qr/Shiny new report/, 'Email body does not have new report';
        unlike  $body, qr/Really old report/, 'Email body does not have old report';
    };
};

subtest 'user with old reports does not get email' => sub {
  $mech->clear_emails_ok;
  $mech->email_count_is(0);

  $mech->create_problems_for_body(4, $oxfordshire->id, 'Really old report', {
      areas      => ',2237,',
      lastupdate => '2014-12-01 07:00:00',
      user       => $user,
  });

  FixMyStreet::Script::ArchiveOldEnquiries::archive($opts);

  my @emails = $mech->get_email;
  $mech->email_count_is(0);
};

subtest 'user with new reports does not get email' => sub {
  $mech->clear_emails_ok;
  $mech->email_count_is(0);

  $mech->create_problems_for_body(4, $oxfordshire->id, 'Shiny new report', {
      areas      => ',2237,',
      user       => $user,
  });

  FixMyStreet::Script::ArchiveOldEnquiries::archive($opts);

  $mech->email_count_is(0);
};

subtest 'can configure comment message' => sub {
  my ($p) = $mech->create_problems_for_body(4, $oxfordshire->id, 'Really old report', {
      areas      => ',2237,',
      lastupdate => '2014-12-01 07:00:00',
      user       => $user,
  });

  $opts->{closure_text} = "This report is now closed";
  FixMyStreet::Script::ArchiveOldEnquiries::archive($opts);

  is $p->comments->first->text, "This report is now closed", "closure text set";
};


subtest 'can provide close message as file' => sub {
    $opts->{closure_text} = '';
    $opts->{closure_file} = path(__FILE__)->parent->child('closure_message.txt')->absolute->stringify;
  my ($p) = $mech->create_problems_for_body(4, $oxfordshire->id, 'Really old report', {
      areas      => ',2237,',
      lastupdate => '2014-12-01 07:00:00',
      user       => $user,
  });

  FixMyStreet::Script::ArchiveOldEnquiries::archive($opts);

  is $p->comments->first->text, "This is a first line.\nThis is a message from a file.", "closure text set";
};

subtest 'can configure closure state' => sub {
  my ($p) = $mech->create_problems_for_body(4, $oxfordshire->id, 'Really old report', {
      areas      => ',2237,',
      lastupdate => '2014-12-01 07:00:00',
      user       => $user,
  });

  $opts->{closed_state} = "no further action";
  FixMyStreet::Script::ArchiveOldEnquiries::archive($opts);

  $p->discard_changes;
  is $p->state, "no further action", "closure state set";
  is $p->comments->first->problem_state, "no further action", "comment problem state set";
};

subtest 'csv file correctly handled' => sub {
    $opts->{reports} = 'doesnotexist.csv';
    FixMyStreet::Script::ArchiveOldEnquiries::update_options($opts);
    throws_ok { FixMyStreet::Script::ArchiveOldEnquiries::get_ids_from_csv } qr/Failed to open/, 'handles missing file';

    my $fh = File::Temp->new;
    my $name = $fh->filename;
    $opts->{reports} = $name;

    for ( qw/ 1 20 3x ten 11 /) {
        print $fh $_ . "\n";
    }
    $fh->seek( 0, SEEK_SET );

    FixMyStreet::Script::ArchiveOldEnquiries::update_options($opts);
    my $ids = FixMyStreet::Script::ArchiveOldEnquiries::get_ids_from_csv;

    is_deeply $ids, [1, 20, 11], 'skips non numeric ids';
};

subtest 'can provide reports as csv' => sub {
    my $fh = File::Temp->new;
    my $name = $fh->filename;

    $opts->{closed_state} = 'fixed';
    $opts->{closure_cutoff} = $opts->{email_cutoff};
    $opts->{email_cutoff} = '';
    $opts->{reports} = $name;

    my @new_reports = $mech->create_problems_for_body(4, $oxfordshire->id, 'newer reports', {
      areas      => ',2237,',
      lastupdate => '2016-12-01 07:00:00',
      user       => $user,
    });

    my @old_reports = $mech->create_problems_for_body(4, $oxfordshire->id, 'older reports', {
      areas      => ',2237,',
      lastupdate => '2015-12-01 07:00:00',
      user       => $user,
    });

    my $alert_new = FixMyStreet::DB->resultset('Alert')->find_or_create(
        {
            user => $user,
            parameter => $new_reports[0]->id,
            alert_type => 'new_updates',
            whensubscribed => '2015-12-01 07:00:00',
            confirmed => 1,
            cobrand => 'default',
        }
    );

    my $alert_old = FixMyStreet::DB->resultset('Alert')->find_or_create(
        {
            user => $user,
            parameter => $old_reports[0]->id,
            alert_type => 'new_updates',
            whensubscribed => '2015-12-01 07:00:00',
            confirmed => 1,
            cobrand => 'default',
        }
    );
    is $alert_new->alerts_sent->count, 0, 'Nothing has been sent for new report alert';
    is $alert_old->alerts_sent->count, 0, 'Nothing has been sent for old report alert';

    my $skipped = pop @new_reports;
    for my $p ( @new_reports, @old_reports ) {
        print $fh $p->id . "\n";
    }

    $fh->seek( 0, SEEK_SET );

    FixMyStreet::Script::ArchiveOldEnquiries::archive($opts);

    $_->discard_changes for ( @old_reports, @new_reports );

    is $old_reports[0]->state, "fixed", "report is closed";
    is $new_reports[0]->state, "fixed", "report is closed";
    is $skipped->state, "confirmed", "report is ignored";

    is $alert_new->alerts_sent->count, 0, 'Archiving did not mark alerts as sent for new report alert';
    is $alert_old->alerts_sent->count, 1, 'Archiving marked alert as sent for old report alert';

    my $alert_sent = $alert_old->alerts_sent->first;
    my $comment = $old_reports[0]->comments->first;
    is $alert_sent->parameter, $comment->id, 'AlertSent created for new comment';
};

subtest 'csv list not acted on if commit not set' => sub {
    my $fh = File::Temp->new;
    my $name = $fh->filename;

    $opts->{reports} = $name;
    $opts->{commit} = 0;

    my @new_reports = $mech->create_problems_for_body(4, $oxfordshire->id, 'newer reports', {
      areas      => ',2237,',
      lastupdate => '2016-12-01 07:00:00',
      user       => $user,
    });

    my @old_reports = $mech->create_problems_for_body(4, $oxfordshire->id, 'older reports', {
      areas      => ',2237,',
      lastupdate => '2015-12-01 07:00:00',
      user       => $user,
    });

    my $alert_new = FixMyStreet::DB->resultset('Alert')->find_or_create(
        {
            user => $user,
            parameter => $new_reports[0]->id,
            alert_type => 'new_updates',
            whensubscribed => '2015-12-01 07:00:00',
            confirmed => 1,
            cobrand => 'default',
        }
    );

    my $alert_old = FixMyStreet::DB->resultset('Alert')->find_or_create(
        {
            user => $user,
            parameter => $old_reports[0]->id,
            alert_type => 'new_updates',
            whensubscribed => '2015-12-01 07:00:00',
            confirmed => 1,
            cobrand => 'default',
        }
    );
    is $alert_new->alerts_sent->count, 0, 'Nothing has been sent for new report alert';
    is $alert_old->alerts_sent->count, 0, 'Nothing has been sent for old report alert';

    my $skipped = pop @new_reports;
    for my $p ( @new_reports, @old_reports ) {
        print $fh $p->id . "\n";
    }

    $fh->seek( 0, SEEK_SET );

    FixMyStreet::Script::ArchiveOldEnquiries::archive($opts);

    $_->discard_changes for ( @old_reports, @new_reports );

    is $old_reports[0]->state, "confirmed", "report is is not updated";
    is $new_reports[0]->state, "confirmed", "report is not updated";
    is $skipped->state, "confirmed", "report is ignored";

    is $alert_new->alerts_sent->count, 0, 'Archiving did not send alert for new report alert';
    is $alert_old->alerts_sent->count, 0, 'Archiving did not send alert for old report alert';

    is $new_reports[0]->comments->count, 0, 'No comment added to report';
};

subtest 'date based updates do not happen without commit' => sub {
    FixMyStreet::override_config {
          ALLOWED_COBRANDS => [ 'oxfordshire' ],
    }, sub {

        $opts->{closure_cutoff} = "2015-01-01 00:00:00";
        $opts->{email_cutoff} = "2016-01-01 00:00:00";
        $opts->{reports} = undef;

        $mech->clear_emails_ok;
        $mech->email_count_is(0);

        my ($report) = $mech->create_problems_for_body(1, $oxfordshire->id, 'Test', {
            areas      => ',2237,',
            user_id    => $user->id,
        });

        my ($report1) = $mech->create_problems_for_body(1, $oxfordshire->id . "," .$west_oxon->id, 'Test', {
            areas      => ',2237,',
            lastupdate => '2016-12-01 07:00:00',
            user       => $user,
        });

        my ($report2) = $mech->create_problems_for_body(1, $oxfordshire->id, 'Test 2', {
            areas      => ',2237,',
            lastupdate => '2015-12-01 08:00:00',
            user       => $user,
            state      => 'investigating',
        });

        my ($report3, $report4) = $mech->create_problems_for_body(2, $oxfordshire->id, 'Test', {
            areas      => ',2237,',
            lastupdate => '2014-12-01 07:00:00',
            user       => $user,
        });

        my ($report5) = $mech->create_problems_for_body(1, $oxfordshire->id . "," .$west_oxon->id, 'Test', {
            areas      => ',2237,',
            lastupdate => '2014-12-01 07:00:00',
            user       => $user,
            state      => 'in progress'
        });

        my $alert = FixMyStreet::DB->resultset('Alert')->find_or_create(
            {
                user => $user,
                parameter => $report1->id,
                alert_type => 'new_updates',
                whensubscribed => '2015-12-01 07:00:00',
                confirmed => 1,
                cobrand => 'default',
            }
        );
        is $alert->alerts_sent->count, 0, 'No alerts for report 1';

        FixMyStreet::Script::ArchiveOldEnquiries::archive($opts);

        $report->discard_changes;
        $report1->discard_changes;
        $report2->discard_changes;
        $report3->discard_changes;
        $report4->discard_changes;
        $report5->discard_changes;

        is $report1->state, 'confirmed', 'Report 1 has been not been updated';
        is $report2->state, 'investigating', 'Report 2 has not been updated';
        is $report3->state, 'confirmed', 'Report 3 has not been updated';
        is $report4->state, 'confirmed', 'Report 4 has not been updated';
        is $report5->state, 'in progress', 'Report 5 has not been updated';

        is $report1->comments->count, 0, 'Report 1 has no comments';
        is $alert->alerts_sent->count, 0, 'No alerts for report 1';

        $mech->email_count_is(0);
    };
};

done_testing();

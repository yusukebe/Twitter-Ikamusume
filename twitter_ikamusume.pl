#!/usr/bin/env perl
use Mojolicious::Lite;
use Net::Twitter::Lite;
use Acme::Ikamusume;
use Plack::Builder;

my $config = plugin('Config');
my $nt = Net::Twitter::Lite->new(
    consumer_key    => $config->{consumer_key},
    consumer_secret => $config->{consumer_secret},
);
app->secret($config->{secret});

get '/' => sub {
    my $self = shift;
    my $tweets;
    if( $self->session('access_token') ) {
        $nt->access_token($self->session('access_token'));
        $nt->access_token_secret($self->session('access_token_secret'));
        for my $tweet ( @{$nt->home_timeline} ) {
            next if $tweet->{user}{protected};
            $tweet->{text} = Acme::Ikamusume->geso($tweet->{text});
            push @$tweets, $tweet;
        }
    }
    $self->stash->{tweets} = $tweets;
    $self->render('index');
};

get '/login' => sub {
    my $self = shift;
    my $url = $nt->get_authorization_url( callback => $self->req->url->base . '/callback' );
    $self->session(
        {
            token        => $nt->request_token,
            token_secret => $nt->request_token_secret
        }
    );
    $self->redirect_to( $url );
};

get '/callback' => sub {
    my $self = shift;
    $nt->request_token( $self->session('token') );
    $nt->request_token_secret( $self->session('token_secret') );
    my $verifier = $self->req->param('oauth_verifier');
    my($access_token, $access_token_secret, $user_id, $screen_name) =
        $nt->request_access_token(verifier => $verifier);
    $self->session(
        {
            access_token        => $access_token,
            access_token_secret => $access_token_secret,
            screen_name         => $screen_name
        }
    );
    $self->redirect_to( $self->req->url->base );
};

get '/logout' => sub {
    my $self = shift;
    $self->session(expires => 1);
    $self->redirect_to( $self->req->url->base );
};

builder {
    enable_if { $_[0]->{REMOTE_ADDR} eq '127.0.0.1' } 
        "Plack::Middleware::ReverseProxy";
    app->start;
};


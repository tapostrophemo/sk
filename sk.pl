#!perl -wT
# sk, a (very) simple wiki. Copyright (c) 2006, 2008, Daniel J. Parks.

use strict;
my $VERSION = '0.2.9.1';

# To install sk, edit this file and set the variables in the CONFIGURATION section.
# Then place this file in a directory on your webserver where Perl scripts are
# allowed to execute. You also need to put the CSS/JS/PNG files in an appropriate
# location. Ensure the server has read/write access to $PAGE_DIR and $DATA_DIR.
# Also, don't make $PAGE_DIR and $DATA_DIR the same directory.

# THE AUTHOR DISCLAIMS ALL RESPONSIBILITY AND LIABILITY FOR ANY HARM DONE TO YOU,
# YOUR DATA, YOUR SYSTEMS, OR TO OTHERS, THEIR DATA, AND THEIR SYSTEMS, THROUGH
# YOUR USE OF THIS PROGRAM. THIS PROGRAM IS RELEASED WITHOUT WARRANTY OF FITNESS
# FOR ANY PARTICULAR USE OR PURPOSE.

use CGI qw(script_name);
use IO::File;
use File::Spec;

### BEGIN CONFIGURATION ###
my $CSS           = '/sk.css';     # (web) path and name of your stylesheet
my $JS            = '/sk.js';      # (web) path and name of the necessary JavaScript
my $IMAGE_DIR     = '/';           # (web) path to location of your images
my $PAGE_DIR      = 'c:/sk/pages'; # (filesystem) path to your pages directory
my $DATA_DIR      = 'c:/sk/data';  # (filesystem) path to your data directory (holds index and search data)
my $START_PAGE    = 'WelcomeToSK'; # wikiname of your start/default page
my $IS_EDITABLE   = 1;             # indicates whether or not pages are editable (hides/shows 'edit' link, allows/disallows new page creation)
my $MAX_PAGE_SIZE = 1024*100*8;    # will limit the size of your pages; see also CGI.pm docs
### END CONFIGURATION ###

$CGI::DISABLE_UPLOADS = 1;
$CGI::POST_MAX = $MAX_PAGE_SIZE;

my $SCRIPT_NAME = script_name();
my $INDEX       = 'Index';
my $SEARCH      = 'Search';
my $ERROR       = 'Error';
my $ALL_PAGES   = File::Spec->join($PAGE_DIR, '*');
my $INDEX_FILE  = File::Spec->join($DATA_DIR, $INDEX);
my $SEARCH_FILE = File::Spec->join($DATA_DIR, $SEARCH);
my $WIKI_WORD   = "[A-Z][a-z]*(?:[A-Z][a-z]*)+";

Wiki->new(CGI->new)->run;

### utility functions ###

sub pagePathsNames { return glob $ALL_PAGES }
sub nameOnly { return (File::Spec->splitpath($_[0]))[2] }
sub pageNames { return map {nameOnly($_)} sort +(pagePathsNames()) }
sub slurp {
  my $name = shift;
  my $fh = IO::File->new($name, 'r');
  die "no such file '$name'"
    unless $fh;
  return join '', $fh->getlines;
}
sub unslurp {
  my ($name, $linesRef) = @_;
  my $fh = IO::File->new($name, 'w');
  die "unable to create '$name' for writing"
    unless $fh;
  print $fh @{$linesRef};
}
sub makeIndex {
  my ($c, $last, @lines) = ('', '', ());
  unlink $INDEX_FILE;
  push @lines, "<h1>$INDEX</h1>\n";
  foreach my $page ( pageNames() ) {
    $c = substr($page, 0, 1);
    if ( $c ne $last ) {
      $last = $c;
      push @lines, "<hr><h2>$c</h2>\n";
    }
    push @lines, "$page\n";
  }
  unslurp($INDEX_FILE, \@lines);
}
sub doSearch {
  my $term = shift;
  my ($found, %matches, @lines) = (0, (), ());
  unlink $SEARCH_FILE;
  foreach my $page ( pagePathsNames() ) {
    $_ = slurp($page);
    $matches{$page} = s/$term/$term/gi;
  }
  my @sorted = map {$_->[1]}
               sort {$b->[0] <=> $a->[0]}
               map {[$matches{$_}, $_]} keys %matches;
  push @lines, "<h1>$SEARCH results for '$term'</h1>\n";
  foreach my $page ( @sorted ) {
    if ( $matches{$page} ) {
      my $desc = 'match' . ($matches{$page} == 1 ? '' : 'es');
      push @lines, sprintf("%s (%d %s)\n", nameOnly($page), $matches{$page}, $desc);
      $found++;
    }
  }
  push @lines, 'no results found'
    unless $found;
  unslurp($SEARCH_FILE, \@lines);
}

package Wiki; ### implements the controller in MVC ###
sub new {
  my ($class, $cgi) = @_;
  return bless {CGI => $cgi}, $class;
}
sub cgi { return shift()->{CGI} }
sub param {
  my ($self, $name) = @_;
  return $self->cgi->param($name);
}
sub run {
  my $self = shift;
  my $action = $self->param('action');
  my $name = $self->param('name');
  eval {
    if    ( $self->cgi->cgi_error )                      { $self->error($self->cgi->cgi_error) }
    elsif ( $name && $action && lc $action eq 'edit' )   { $self->edit($name) }
    elsif ( $name && $action && lc $action eq 'save' )   { $self->save($name) }
    elsif (          $action && lc $action eq 'search' ) { $self->search }
    elsif (          $action && lc $action eq 'index' )  { $self->index }
    else {               $name = $START_PAGE unless $name; $self->view($name) }
  };
  if ( $@ ) {
    $self->error($@);
  }
}
sub index {
  my $self = shift;
  eval { ::makeIndex() };
  if ( $@ ) {
    $self->error('unable to generate index');
    return;
  }
  PageView->new->viewing(Page->getDataByName($INDEX), $self->cgi, pageNames());
}
sub search {
  my $self = shift;
  my $term = $self->param('term');
  if ( ! $term ) {
    SearchForm->new->viewing(Page->new($SEARCH), $self->cgi);
  }
  else {
    eval { ::doSearch($term) };
    if ( $@ ) {
      $self->error('unable to generate search results');
      return;
    }
    PageView->new->viewing(Page->getDataByName($SEARCH), $self->cgi, pageNames());
  }
}
sub view {
  my ($self, $name) = @_;
  PageView->new->viewing(Page->getByName($name), $self->cgi, pageNames());
}
sub edit {
  my ($self, $name) = @_;
  PageView->new->editing(Page->getByName($name), $self->cgi);
}
sub save {
  my ($self, $name) = @_;
  eval { Page->save($name, $self->param('text')) };
  if ( $@ ) {
    $self->error("unable to save page '$name'. " . $@);
    return;
  }
  $self->view($name);
}
sub error {
  my ($self, $msg) = @_;
  my $page = Page->new($ERROR);
  $page->setText("There has been an error. Please contact the site administrator\n" .
                 "with the error message listed above.");
  if ( $msg =~ /unable to (save|generate)/ ) {
    my $culprit = $msg =~ /save/ ? '$PAGE' : '$DATA';
    $page->setText("Please ask your administrator to check if the webserver has\n" .
                   "read/write access to ${culprit}_DIR.");
  }
  ErrorView->new->viewing($page, $self->cgi, $msg);
}
sub pageNames {
  my @pageNames = ::pageNames();
  return \@pageNames;
}

package Page; ### implemenets the model in MVC ###
sub new {
  my ($class, $name) = @_;
  return bless {NAME => $name, TEXT => '*New Page*', IS_NEW => 1}, $class;
}
sub save {
  my ($class, $name, $text) = @_;
  if ( $name =~ /^($WIKI_WORD)$/ ) {
    ::unslurp(File::Spec->join($PAGE_DIR, $1), [$text]);
  }
  else {
    die "bad page name for saving: $name";
  }
}
sub name { return shift()->{NAME} }
sub text { return shift()->{TEXT} }
sub setText {
  my ($self, $text) = @_;
  $self->{TEXT} = $text;
}
sub isNew { return shift()->{IS_NEW} }
sub getDataByName {
  my ($class, $name) = @_;
  return $class->new($name)->_get($DATA_DIR);
}
sub getByName {
  my ($class, $name) = @_;
  return $class->new($name)->_get($PAGE_DIR);
}
sub _get {
  my ($self, $dir) = @_;
  eval {
    die("bad page name for reading: " . $self->name)
      unless $self->name =~ /^[A-Za-z]+$/; # allow for retrieving non-wiki-word pages (e.g., 'Index')
    $self->setText(::slurp(File::Spec->join($dir, $self->name)));
    $self->{IS_NEW} = 0;
  };
  if ( $@ ) {
    die "unexpected error: $@"
      unless $@ =~ /no such file/i;
  }
  return $self;
}

package View; ### implements base class for views in MVC in this app ###
sub new { return bless {}, shift }
sub render {
  my ($self, $title, $content, $cgi, $script) = @_;
  my @props = (
    -title => "sk ($VERSION) - $title",
    -style => {src => $CSS},
    -dtd   => '-//W3C//DTD HTML 4.01 Transitional//EN',
  );
  push @props, (-script => {-src => $JS}, -onload => $script)
    if $script;
  print $cgi->header, $cgi->start_html(@props), "<pre>$content</pre>", $cgi->end_html;
}
sub controls {
  my ($self, $page) = @_;
  return '<hr>' .
    "[<a href=\"$SCRIPT_NAME\">home</a>]" .
    $self->editLink($page) .
    "[<a href=\"$SCRIPT_NAME?action=search\">search</a>]" .
    "[<a href=\"$SCRIPT_NAME?action=index\">index</a>]";
}
sub editLink {
  my ($self, $page) = @_;
  return ($IS_EDITABLE && ! grep {$_ eq $page->name} ($INDEX, $SEARCH, $ERROR))
    ? "[<a href=\"$SCRIPT_NAME?action=edit&name=" . $page->name . "\">edit</a>]"
    : '';
}

package PageView; ### implements one type of view in MVC ###
use base 'View';
sub viewing {
  my ($self, $page, $cgi, $pageNames) = @_;
  if ( $page->isNew ) {
    $self->editing($page, $cgi);
    return;
  }
  $self->render($page->name, links($page, $pageNames) . $self->controls($page), $cgi);
}
sub links {
  my ($page, $pageNames) = @_;
  local $_ = $page->text;
  s/\b($WIKI_WORD)\b/linkIfIn($1, $pageNames)/ge;
  return $_;
}
sub linkIfIn {
  my ($name, $pageNames) = @_;
  return grep({$name eq $_} @{$pageNames})
    ? "<a href=\"$SCRIPT_NAME?name=$name\">$name</a>"
    : "$name<a href=\"$SCRIPT_NAME?name=$name\">?</a>";
}
sub editing {
  my ($self, $page, $cgi) = @_;
  my $content = $page->isNew
    ? '<h1>The page "' . $page->name . '" does not exist</h1>'
    : '<h1>Edit "' . $page->name . '"</h1>';
  if ( $IS_EDITABLE ) {
    $content .= "\n";
    $content .= $page->isNew
      ? 'Enter text and click "Save" if you want to create this page'
      : 'Click "Save" when finished to save changes';
    $content .= ', or your browser\'s "Back" button to cancel.';
    $content .= form($page, $cgi);
  }
  else {
    $content .= $self->controls($page);
  }
  $self->render($page->name, $content, $cgi, 'initPage()');
}
sub form {
  my ($page, $cgi) = @_;
  $cgi->delete('action');
  return $cgi->start_form(-action => $SCRIPT_NAME) .
    '<div id="outer"><div id="inner" style="width:470px">' .
    $cgi->textarea(-name => 'text', -id => 'text', -default => $page->text, -wrap => 'off', -style => 'width:470px; height:230px') .
    $cgi->hidden(-name => 'action', -default => 'save') .
    $cgi->hidden(-name => 'name', -default => $page->name) .
    '<table id="handleContainer" border="0" cellspacing="0" cellpadding="0" width="100%"><tr>' .
    ' <td>' . $cgi->submit(-value => 'Save') . '</td>' .
    ' <td align="right">' .
    '  <table border="0" cellspacing="0" cellpadding="0">' .
    '   <tr>' .
    "    <td><img src=\"${IMAGE_DIR}resizeHandle-1-1.png\" style=\"width:35px; height:10px\"></td>" .
    "    <td><img src=\"${IMAGE_DIR}resizeHandle-1-2.png\" style=\"width:14px; height:10px\"></td>" .
    '   </tr>' .
    '   <tr>' .
    "    <td><img src=\"${IMAGE_DIR}resizeHandle-2-1.png\" style=\"width:35px; height:14px\"></td>" .
    "    <td><img src=\"${IMAGE_DIR}resizeHandle-2-2.png\" style=\"width:14px; height:14px; cursor:nw-resize\" alt=\"resize\" id=\"resizeHandle\"></td>" .
    '   </tr>' .
    '  </table>' .
    ' </td>' .
    '</tr></table>' .
    '</div></div>' .
    $cgi->end_form;
}

package SearchForm; ### another view in MVC ###
use base 'View';
sub viewing {
  my ($self, $page, $cgi) = @_;
  my $content = "<h1>$SEARCH</h1>" . $cgi->start_form(-action => $SCRIPT_NAME) .
    $cgi->textfield(-name => 'term') .
    $cgi->hidden(-name => 'action', -default => 'search') .
    $cgi->submit(-value => $SEARCH) . $cgi->end_form;
  $self->render($SEARCH, $content . $self->controls($page), $cgi);
}

package ErrorView; ### yet another MVC view ###
use base 'View';
sub viewing {
  my ($self, $page, $cgi, $msg) = @_;
  my $content = "<h1>$ERROR: $msg</h1>\n" . $page->text . $self->controls($page);
  $self->render($page->name, $content, $cgi);
}


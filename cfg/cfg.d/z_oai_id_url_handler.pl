#####
#
# Experimental... see: https://github.com/uol-library/eprints-oai-id
#
#####

$c->add_trigger( EP_TRIGGER_URL_REWRITE, sub
{
        my( %args ) = @_;

	my( $repo, $uri, $rc, $r ) = @args{ qw( repository uri return_code request ) };
        
	if( defined $uri && ($uri =~ m! ^/id/oai_id/(.*)$ !x ) ) 
	{
		my $oai_id = $1;

		# if request wants XML as a priority, send them to OAI interface
		# if not, redir them to landing page
		my $accept = $r->headers_in->get('Accept');
		$accept ||= "*/*";
		my @a = EPrints::Apache::CRUD::parse_media_range( $accept );

		# TODO: consider full stack of export formats - who might request using an OAI_ID, and what might they want in return!?
		# Currently the code below will respond with the summary page if `Accept: text/html, text/xml` is sent,
		# due to alphbetical ordering in parse_media_range
		my $redir_to_oai;
		foreach my $acc ( @a )
		{
			#TODO get the mime types from a plugin? Remember to keep things lightweight in URL REWRITE triggers!
			if( @$acc[0] eq "text/xml" )
			{
				$redir_to_oai = 1;
				last;
			}
			elsif( @$acc[0] eq "text/html" || @$acc[0] eq "application/xhtml+xml" ) 
			{
				$redir_to_oai = 0;
				last;
			}
		}

		if( $redir_to_oai )
		{
			#send to oai2 interface. Doesn't check whether the OAI ID makes any sense, let the OAI interface do that.
			my $oai_uri = URI->new( $repo->config( "oai", "v2", "base_url" ) );
			$oai_uri->query_form(
				verb 		=> "GetRecord",
				metadataPrefix 	=> "oai_dc",
				identifier 	=> $oai_id,
			);
			${$rc} = EPrints::Apache::Rewrite::redir( $r, "$oai_uri" );
                        return EP_TRIGGER_DONE;

		}
		else
		{
			my $ep_id = EPrints::OpenArchives::from_oai_identifier( $repo, $oai_id );
			
			#TODO: improve this response (falls-back to standard 404)
			return undef unless EPrints::Utils::is_set( $ep_id );

			my $eprint = EPrints::DataObj::EPrint->new( $repo, $ep_id );
			if( defined $eprint )
			{
				${$rc} = EPrints::Apache::Rewrite::redir( $r, $eprint->get_url );
	                        return EP_TRIGGER_DONE;
			}
			#TODO: improve this response (also falls-back to standard 404)
		}
	}

        return EP_TRIGGER_OK;
} );

# TODO: Add a function to allow easy rendering of OAI_ID (as a link?) on the item summary page, essentially this:
# EPrints::OpenArchives::to_oai_identifier( EPrints::OpenArchives::archive_id( $repo ), $eprint->get_id )
#

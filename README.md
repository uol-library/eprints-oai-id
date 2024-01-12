# eprints-oai-id

This 'experiment' is the result of a discussion with CORE regarding use of OAI IDs as 'persistent' identifiers.
Whilst I personally have reservations about the term 'persistent' alongside these identifiers, the question as to whether they _could_ be used more on an EPrints instance is hopefully answered here.

This code demonstrates an interface that supports use of the OAI ID and will redirect requests to [server-name]/id/oai_id/[oai identifier] to either the item landing page or the OAI2 interface, based on the HTTP headers sent.

The OAI specification defines (https://www.openarchives.org/OAI/openarchivesprotocol.html#HTTPResponseFormat):

> Content-Type returned for all OAI-PMH requests must be text/xml

This code uses the 'Accept' header to determine the response. If `text/xml` is more preferred than `text/html` or `application/xhtml+xml` (two formats the EPrints SummaryPage produces) then the response is a redirect to the OAI2 interface.
The default is to redirect to the (human friendly) summary page.

## Musings

### Content Negotiation

EPrints already does content negiotiation in two modules: `EPrints::Apache::Rewrite` and `EPrints::Apache::CRUD`. Both these contain a `content_negotiate_best_plugin` method to work out which plugin is best to respond with.
The OAI-PMH interface itself isn't a plugin, although the metadata formats it supports are. This means we can't immediately use either of the existing content-negitiation methods. An OAI-PMH plugin could be _spoofed_ before calling one of these methods, but this feels _bad_. If OAI_IDs gain wider use, the OAI2 interface _could_ be created as an export plugin in the EPrints core..

The code defaults to redirecting to the summary page. If `text/xml`, `text/html` and `application/xhtml+xml` were equally weighted in the Accept header, an alternative approach would be to respond with a '300 Multople Choices' (https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/300), although I'm not sure how expected this would be.

Ref: https://www.rfc-editor.org/rfc/rfc9110.html#name-content-negotiation-fields

Other modules that are relevant:
* https://github.com/gisle/http-negotiate/blob/master/lib/HTTP/Negotiate.pm - feels unnecessary to include another perl module just for this, although it could be useful in other EPrints code.
* https://github.com/libwww-perl/HTTP-Message/blob/master/lib/HTTP/Headers/Util.pm - EPrints currently uses this.
* https://github.com/reneeb/HTTP-Accept/blob/master/lib/HTTP/Accept.pm - uses Moo framework. Too heaveyweight for this purpose IMHO.

### Generating URL for OAI record

The OAI2 specification defines a `base_url` element. EPrints uses a config hash to store this value (see ~/lib/defaultcfg/cfg.d/oai.pl): `$oai->{v2}->{base_url} = $c->{perl_url}."/oai2";`.
In the human-readable version of the OAI2 interface, the link to a specific record is created in the XSLT (~lib/static/oai2.xsl):
`"?verb=GetRecord&amp;metadataPrefix=oai_dc&amp;identifier={oai:identifier}">oai_dc</a>`

The code recreates the above URL.

### Other requested formats

The code could be extended to support other response formats based on the Accept headers e.g. a request with the header `Accept: text/n3, text/xml, */*` could respond with the RDF+N3 representation of the record. This would be a redirect to the appropriate export interface.

### EPrints - existing parsing of the `Accept` header

This experimental code re-use the `EPrints::Apache::CRUD::parse_media_range` method to parse the incoming Accept header.
The documentation claims to sort the header by:
- the quality score (defaulting to 1 if not specified)
- whether a sub-type is defined/wildcard `text/*` vs `text/xml`
- whether additional parameters have been supplied for the format

The actual result of the sort results formats with equal quality-scores being alphabetically sorted by mime-type and/or sub-type, so `application/html` would come before `application/xml`, and both would come before `text/html`.
Whilst this isn't an issue for us, it did confuse me somewhat.

// Copyright (c) 2019-2020 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.
module http

import net.urllib
import net.http.chunked

const (
	max_redirects = 4
	content_type_default = 'text/plain'
)

pub struct Request {
pub:
	method     string
	headers    map[string]string
	cookies    map[string]string
	data       string
	url        string
	user_agent string
	verbose    bool
mut:
	user_ptr   voidptr
	ws_func    voidptr
}

pub struct FetchConfig {
pub mut:
	method     string
	data       string=''
	params     map[string]string=map[string]string
	headers    map[string]string=map[string]string
	cookies    map[string]string=map[string]string
	user_agent string='v'
	verbose    bool=false
}

pub struct Response {
pub:
	text        string
	headers     map[string]string
	cookies     map[string]string
	status_code int
}

pub fn get(url string) ?Response {
	return fetch_with_method('GET', url, FetchConfig{})
}

pub fn post(url, data string) ?Response {
	return fetch_with_method('POST', url, {
		data: data
		headers: {
			'Content-Type': content_type_default
		}
	})
}

pub fn post_form(url string, data map[string]string) ?Response {
	return fetch_with_method('POST', url, {
		headers: {
			'Content-Type': 'application/x-www-form-urlencoded'
		}
		data: url_encode_form_data(data)
	})
}

pub fn put(url, data string) ?Response {
	return fetch_with_method('PUT', url, {
		data: data
		headers: {
			'Content-Type': content_type_default
		}
	})
}

pub fn patch(url, data string) ?Response {
	return fetch_with_method('PATCH', url, {
		data: data
		headers: {
			'Content-Type': content_type_default
		}
	})
}

pub fn head(url string) ?Response {
	return fetch_with_method('HEAD', url, FetchConfig{})
}

pub fn delete(url string) ?Response {
	return fetch_with_method('DELETE', url, FetchConfig{})
}

pub fn fetch(_url string, config FetchConfig) ?Response {
	if _url == '' {
		return error('http.fetch: empty url')
	}
	url := build_url_from_fetch(_url, config) or {
		return error('http.fetch: invalid url ${_url}')
	}
	data := config.data
	method := config.method.to_upper()
	req := Request{
		method: method
		url: url
		data: data
		headers: config.headers
		cookies: config.cookies
		user_agent: config.user_agent
		ws_func: 0
		user_ptr: 0
		verbose: config.verbose
	}
	res := req.do() or {
		return error(err)
	}
	return res
}

pub fn get_text(url string) string {
	resp := fetch(url, {
		method: 'GET'
	}) or {
		return ''
	}
	return resp.text
}

pub fn url_encode_form_data(data map[string]string) string {
	mut pieces := []string
	for _key, _value in data {
		key := urllib.query_escape(_key)
		value := urllib.query_escape(_value)
		pieces << '$key=$value'
	}
	return pieces.join('&')
}

fn fetch_with_method(method string, url string, _config FetchConfig) ?Response {
	mut config := _config
	config.method = method
	return fetch(url, config)
}

fn build_url_from_fetch(_url string, config FetchConfig) ?string {
	mut url := urllib.parse(_url) or {
		return error(err)
	}
	params := config.params
	if params.keys().len == 0 {
		return url.str()
	}
	mut pieces := []string
	for key in params.keys() {
		pieces << '${key}=${params[key]}'
	}
	mut query := pieces.join('&')
	if url.raw_query.len > 1 {
		query = url.raw_query + '&' + query
	}
	url.raw_query = query
	return url.str()
}

fn (req mut Request) free() {
	req.headers.free()
}

fn (resp mut Response) free() {
	resp.headers.free()
}

// add_header adds the key and value of an HTTP request header
pub fn (req mut Request) add_header(key, val string) {
	req.headers[key] = val
}

pub fn parse_headers(lines []string) map[string]string {
	mut headers := map[string]string
	for i, line in lines {
		if i == 0 {
			continue
		}
		words := line.split(': ')
		if words.len != 2 {
			continue
		}
		headers[words[0]] = words[1]
	}
	return headers
}

// do will send the HTTP request and returns `http.Response` as soon as the response is recevied
pub fn (req &Request) do() ?Response {
	mut url := urllib.parse(req.url) or {
		return error('http.Request.do: invalid url ${req.url}')
	}
	mut rurl := url
	mut resp := Response{}
	mut no_redirects := 0
	for {
		if no_redirects == max_redirects {
			return error('http.request.do: maximum number of redirects reached ($max_redirects)')
		}
		qresp := req.method_and_url_to_response(req.method, rurl) or {
			return error(err)
		}
		resp = qresp
		if !(resp.status_code in [301, 302, 303, 307, 308]) {
			break
		}
		// follow any redirects
		mut redirect_url := resp.headers['Location']
		if redirect_url.len > 0 && redirect_url[0] == `/` {
			url.set_path(redirect_url) or {
				return error('http.request.do: invalid path in redirect: "$redirect_url"')
			}
			redirect_url = url.str()
		}
		qrurl := urllib.parse(redirect_url) or {
			return error('http.request.do: invalid URL in redirect "$redirect_url"')
		}
		rurl = qrurl
		no_redirects++
	}
	return resp
}

fn (req &Request) method_and_url_to_response(method string, url net_dot_urllib.URL) ?Response {
	host_name := url.hostname()
	scheme := url.scheme
	p := url.path.trim_left('/')
	path := if url.query().size > 0 { '/$p?${url.query().encode()}' } else { '/$p' }
	mut nport := url.port().int()
	if nport == 0 {
		if scheme == 'http' {
			nport = 80
		}
		if scheme == 'https' {
			nport = 443
		}
	}
	// println('fetch $method, $scheme, $host_name, $nport, $path ')
	if scheme == 'https' {
		// println('ssl_do( $nport, $method, $host_name, $path )')
		res := req.ssl_do(nport, method, host_name, path) or {
			return error(err)
		}
		return res
	}
	else if scheme == 'http' {
		// println('http_do( $nport, $method, $host_name, $path )')
		res := req.http_do(nport, method, host_name, path) or {
			return error(err)
		}
		return res
	}
	return error('http.request.method_and_url_to_response: unsupported scheme: "$scheme"')
}

fn parse_response(resp string) Response {
	// TODO: Header data type
	mut headers := map[string]string
	// TODO: Cookie data type
	mut cookies := map[string]string
	first_header := resp.all_before('\n')
	mut status_code := 0
	if first_header.contains('HTTP/') {
		val := first_header.find_between(' ', ' ')
		status_code = val.int()
	}
	mut text := ''
	// Build resp headers map and separate the body
	mut nl_pos := 3
	mut i := 1
	for {
		old_pos := nl_pos
		nl_pos = resp.index_after('\n', nl_pos + 1)
		if nl_pos == -1 {
			break
		}
		h := resp[old_pos + 1..nl_pos]
		// End of headers
		if h.len <= 1 {
			text = resp[nl_pos + 1..]
			break
		}
		i++
		pos := h.index(':') or {
			continue
		}
		// if h.contains('Content-Type') {
		// continue
		// }
		key := h[..pos]
		val := h[pos + 2..]
		if key == 'Set-Cookie' {
			parts := val.trim_space().split('=')
			cookies[parts[0]] = parts[1]
		}
		headers[key] = val.trim_space()
	}
	if headers['Transfer-Encoding'] == 'chunked' {
		text = chunked.decode(text)
	}
	return Response{
		status_code: status_code
		headers: headers
		cookies: cookies
		text: text
	}
}

fn (req &Request) build_request_headers(method, host_name, path string) string {
	ua := req.user_agent
	mut uheaders := []string
	if !('Host' in req.headers) {
		uheaders << 'Host: $host_name\r\n'
	}
	if !('User-Agent' in req.headers) {
		uheaders << 'User-Agent: $ua\r\n'
	}
	if req.data.len > 0 && !('Content-Length' in req.headers) {
		uheaders << 'Content-Length: ${req.data.len}\r\n'
	}
	for key, val in req.headers {
		if key == 'Cookie' {
			continue
		}
		uheaders << '${key}: ${val}\r\n'
	}
	uheaders << req.build_request_cookies_header()
	return '$method $path HTTP/1.1\r\n' + uheaders.join('') + 'Connection: close\r\n\r\n' + req.data
}

fn (req &Request) build_request_cookies_header() string {
	if req.cookies.keys().len < 1 {
		return ''
	}
	mut cookie := []string
	for key, val in req.cookies {
		cookie << '$key: $val'
	}
	if 'Cookie' in req.headers && req.headers['Cookie'] != '' {
		cookie << req.headers['Cookie']
	}
	return 'Cookie: ' + cookie.join('; ') + '\r\n'
}

pub fn unescape_url(s string) string {
	panic('http.unescape_url() was replaced with urllib.query_unescape()')
}

pub fn escape_url(s string) string {
	panic('http.escape_url() was replaced with urllib.query_escape()')
}

pub fn unescape(s string) string {
	panic('http.unescape() was replaced with http.unescape_url()')
}

pub fn escape(s string) string {
	panic('http.escape() was replaced with http.escape_url()')
}

type wsfn fn(s string, ptr voidptr)

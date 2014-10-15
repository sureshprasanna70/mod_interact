%%%----------------------------------------------------------------------

%%% File    : mod_offline_prowl.erl
%%% Author  : Robert George <rgeorge@midnightweb.net>
%%% Purpose : Forward offline messages to prowl
%%% Created : 31 Jul 2010 by Robert George <rgeorge@midnightweb.net>
%%%
%%%
%%% Copyright (C) 2010   Robert George
%%%
%%% This program is free software; you can redistribute it and/or
%%% modify it under the terms of the GNU General Public License as
%%% published by the Free Software Foundation; either version 2 of the
%%% License, or (at your option) any later version.
%%%
%%% This program is distributed in the hope that it will be useful,
%%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
%%% General Public License for more details.
%%%
%%% You should have received a copy of the GNU General Public License
%%% along with this program; if not, write to the Free Software
%%% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
%%% 02111-1307 USA
%%%
%%%----------------------------------------------------------------------

-module(mod_offline_post).
-author('rgeorge@midnightweb.net').

-behaviour(gen_mod).

-export([start/2,
         init/2,
         stop/1,
         send_notice/3]).

-define(PROCNAME, ?MODULE).

-include("ejabberd.hrl").
-include("jlib.hrl").

start(Host, Opts) ->
  register(?PROCNAME,spawn(?MODULE, init, [Host, Opts])),  
  inets:start(),
  ok.

init(Host, _Opts) ->
  inets:start(),
  ssl:start(),
  ejabberd_hooks:add(offline_message_hook, Host, ?MODULE, send_notice, 30),
  ok.

stop(Host) ->
  ejabberd_hooks:delete(offline_message_hook, Host,?MODULE, send_notice, 30),
  ok.

send_notice(_From, To, Packet) ->
  Body = xml:get_path_s(Packet, [{elem, list_to_binary("body")}, cdata]),
  Type = xml:get_tag_attr_s(list_to_binary("type"), Packet),
  PostUrl = "http://54.183.143.220/testpush.php",
  if (Type == <<"chat">>) and (Body /= <<"">>) ->
       Sep = "&",
       Post = [
               "to=", To#jid.luser, Sep,
               "from=", _From#jid.luser, Sep,
               "body=", url_encode(binary_to_list(Body)), Sep],
       httpc:request(post, {PostUrl, [], "application/x-www-form-urlencoded", list_to_binary(Post)},[],[]),
       ok;
     true ->
       ok
  end.
url_encode([H|T]) when is_list(H) ->
  [url_encode(H) | url_encode(T)];
url_encode([H|T]) ->
  if
    H >= $a, $z >= H ->
      [H|url_encode(T)];
    H >= $A, $Z >= H ->
      [H|url_encode(T)];
    H >= $0, $9 >= H ->
      [H|url_encode(T)];
    H == $_; H == $.; H == $-; H == $/; H == $: -> % FIXME: more..
      [H|url_encode(T)];
    true ->
      case integer_to_hex(H) of
        [X, Y] ->
          [$%, X, Y | url_encode(T)];
        [X] ->
          [$%, $0, X | url_encode(T)]
      end
  end;
url_encode([]) ->
  [].
integer_to_hex(I) ->
  case catch erlang:integer_to_list(I, 16) of
    {'EXIT', _} -> old_integer_to_hex(I);
    Int -> Int
  end.
old_integer_to_hex(I) when I < 10 ->
  integer_to_list(I);
old_integer_to_hex(I) when I < 16 ->
  [I-10+$A];
old_integer_to_hex(I) when I >= 16 ->
  N = trunc(I/16),
  old_integer_to_hex(N) ++ old_integer_to_hex(I rem 16).	

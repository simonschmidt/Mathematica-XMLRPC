(* ::Package:: *)

(************************************************************************)
(* This file was generated automatically by the Mathematica front end.  *)
(* It contains Initialization cells from a Notebook file, which         *)
(* typically will have the same name as this file except ending in      *)
(* ".nb" instead of ".m".                                               *)
(*                                                                      *)
(* This file is intended to be loaded into the Mathematica kernel using *)
(* the package loading commands Get or Needs.  Doing so is equivalent   *)
(* to using the Evaluate Initialization Cells menu command in the front *)
(* end.                                                                 *)
(*                                                                      *)
(* DO NOT EDIT THIS FILE.  This entire file is regenerated              *)
(* automatically each time the parent Notebook file is saved in the     *)
(* Mathematica front end.  Any changes you make to this file will be    *)
(* overwritten.                                                         *)
(************************************************************************)



BeginPackage["XMLRPC`",{"JLink`"}]



Unprotect[XMLRPCCall];
XMLRPCCall::usage="XMLRPCCall[url, method, args...] send an XML-RPC request";
XMLRPC::parseu="Unknown element when parsing response `1`";
XMLRPC::notimpl="Not implemented (`1`)";
XMLRPC::httperr="HTTP request failed (`1`)";



Begin["`Private`"]
ClearAll[parseResponse,httpPOST,strToNum,createRequest,encodeArgument]
$packageVersion="0.1";
$debug=False;


(* import integers that might be negative and larger than int32 without having to use ToExpression or ImportString *)
strToNum[s_String]:=System`Convert`TableDump`ParseTable[
{{s}},
{{{" "},{" "}},{"-","+"},"."},False][[1,1]]



httpPOST::usage="httpPOST[url,body] send a POST request";
httpPOST[url_String,body_String]:=Module[{requestJsonString,client,method,entity,responseCode,response,responseRules,responseExpression},
JavaBlock[
client=JavaNew["org.apache.commons.httpclient.HttpClient"];
method=JavaNew["org.apache.commons.httpclient.methods.PostMethod",url];
entity=JavaNew["org.apache.commons.httpclient.methods.StringRequestEntity",body];
method@setRequestEntity[entity];
method@setRequestHeader["Content-Type","text/xml"];
responseCode=client@executeMethod[method];
If[responseCode===200,
method@getResponseBodyAsString[]
,
Message[XMLRPC::httperr,responseCode];
$Failed
]
]]



parseResponse::usage="parseResponse[xml_] converts a xml-rpc response to Mathematica expression";
parseResponse[XMLObject["Document"][_,v_,_]]:=parseResponse@v
parseResponse[XMLElement["methodResponse",_,{e_XMLElement}]]:=parseResponse@e

parseResponse[XMLElement["params"|"param"|"value"|"array",_,{e_XMLElement}]]:=parseResponse@e

(* Various types *)
parseResponse[XMLElement["data",_,e:{___XMLElement}]]:=parseResponse/@e
parseResponse[XMLElement["string",_,{s_:""}]]:=s
parseResponse[XMLElement["int"|"i4",_,{s_}]]:=strToNum@s
parseResponse[XMLElement["double",_,{s_}]]:=Internal`StringToDouble@s
parseResponse[XMLElement["boolean",_,{"1"}]]=True
parseResponse[XMLElement["boolean",_,{"0"}]]=False
parseResponse[XMLElement["dateTime.iso8601",_,{s_}]]:=DateList[s]
parseResponse[XMLElement["nil",_,_]]=Null
parseResponse[XMLElement["base64",_,{s_}]]:=(Message[XMLRPC::notimpl,"base64"];s)



(* Structs *)
parseResponse[XMLElement["struct",_,members:{___XMLElement}]]:=
Cases[
members,
XMLElement["member",{},{
XMLElement["name",_,{name_}],
XMLElement["value",_,{e_XMLElement}]
}]:>(name->parseResponse@e)];

(* Errors *)
parseResponse[XMLElement["fault",_,{e_XMLElement}]]:=(Message[XMLRPC::fault,#];#)&@parseResponse@e
parseResponse[e_]:=(Message[XMLRPC::parseu,e];$Failed)





createRequest::usage="createRequest[method, args] create XML-RPC request payload";
createRequest[methodName_String,args___]:=
ExportString[
XMLObject["Document"][{XMLObject["Declaration"]["Version"->"1.0"]},
XMLElement["methodCall",{},
{XMLElement["methodName",{},{methodName}],
XMLElement["params",{},
Map[
XMLElement["param",{},
{XMLElement["value",{},
{encodeArgument[#]}]}]&
,{args}]
]}
],
{}
],
"XML","Entities"->"HTML","ElementFormatting"->None
]

encodeArgument::usage="encodeArgument[e] encodes Mathematica expression as XML-RPC"
(* Basic types *)
encodeArgument[s_String]:=
XMLElement["string",{},{s}]
encodeArgument[i_Integer]:=
XMLElement["int",{},{ToString@i}]
encodeArgument[b:(True|False)]:=XMLElement["boolean",{},{ToString@Boole@b}]
encodeArgument[n_?NumericQ]:=
XMLElement["double",{},{ToString@n}]

encodeArgument[s:{__Rule}]:=
XMLElement["struct",{},
XMLElement["member",{},{
XMLElement["name",{},{#1}],
XMLElement["value",{},{encodeArgument@#2}]
}]&@@@s
]

encodeArgument[l_List]:=
XMLElement["array",{},
{XMLElement["data",{},
XMLElement["value",{},{encodeArgument[#]}]&/@l
]}
]

encodeArgument[e_]:=(Message[XMLRPC::unknown,e];Abort[])



(* Multiple calls in one request *)
XMLRPCCall[url_String,calls:{{_String,___}..}]:=
Replace[
XMLRPCCall[url,"system.multicall",{"methodName"->#1,"params"->{##2}}&@@@calls],
e:Except[{__Rule}]:>First@e,
{1}]

XMLRPCCall[url_String,methodName_String,params___]:=Module[{payload,answer},
JavaBlock[
payload=createRequest[methodName,params];
If[$debug,Print["Payload: \n",payload]];

answer=httpPOST[url,payload];
If[$debug,Print["Received: \n",answer]];
If[answer===$Failed,Return[answer,Module]];

answer=ImportString[answer,"XML"];
If[$debug,Print["Decoding answer"]];
parseResponse@answer
]]



End[]


Protect[XMLRPCCall];
EndPackage[]




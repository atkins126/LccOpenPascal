unit lcc_node;

{$IFDEF FPC}
{$mode objfpc}{$H+}
{$ENDIF}

interface

{$I ..\lcc_compilers.inc}

uses
  Classes,
  SysUtils,
  {$IFDEF FPC}
    contnrs,
    {$IFNDEF FPC_CONSOLE_APP}
      ExtCtrls,
    {$ENDIF}
  {$ELSE}
    System.Types,
    FMX.Types,
    System.Generics.Collections,
  {$ENDIF}
  lcc_protocol_utilities,
  lcc_defines,
  lcc_node_messages,
  lcc_utilities,
  lcc_alias_server,
  lcc_train_server;

const
  ERROR_CONFIGMEM_ADDRESS_SPACE_MISMATCH = $0001;

  TIMEOUT_TIME = 100; // milli seconds
  TIMEOUT_CONTROLLER_NOTIFY_WAIT = 5000;  // 5 seconds
  TIMEOUT_CONTROLLER_RESERVE_WAIT = 5000;
  TIMEOUT_NODE_VERIFIED_WAIT = 800;       // 800ms
  TIMEOUT_NODE_ALIAS_MAPPING_WAIT = 1000;       // 800ms
  TIMEOUT_CREATE_TRAIN_WAIT = 1000;       // 1000ms
  TIMEOUT_SNIP_REPONSE_WAIT = 500;
  TIMEOUT_LISTENER_ATTACH_TRAIN_WAIT = 5000;       // per listener, will have to map CAN Alias if on CAN so may take a bit...

const

 CDI_XML: string = (
'<?xml version="1.0" encoding="utf-8"?>'+
'<?xml-stylesheet type="text/xsl" href="http://openlcb.org/trunk/prototypes/xml/xslt/cdi.xsl"?>'+
'<cdi xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://openlcb.org/trunk/specs/schema/cdi.xsd">'+
	'<identification>'+
		'<manufacturer>Mustangpeak</manufacturer>'+
		'<model>TC1000</model>'+
		'<hardwareVersion>1.0.0.0</hardwareVersion>'+
		'<softwareVersion>1.0.0.0</softwareVersion>'+
	'</identification>'+
	'<segment origin="1" space="253">'+
		'<name>User</name>'+
		'<description>User defined information</description>'+
		'<group>'+
			'<name>User Data</name>'+
			'<description>Add your own unique node info here</description>'+
			'<string size="63">'+
				'<name>User Name</name>'+
			'</string>'+
			'<string size="64">'+
				'<name>User Description</name>'+
			'</string>'+
		'</group>'+
	'</segment>'+
'</cdi>');


type
  TLccNode = class;

    { TDatagramQueue }

  TDatagramQueue = class
  private
    {$IFDEF DELPHI}
    FQueue: TObjectList<TLccMessage>;
    {$ELSE}
    FQueue: TObjectList;
    {$ENDIF}
    FSendMessageFunc: TOnMessageEvent;
  protected
    {$IFDEF DELPHI}
    property Queue: TObjectList<TLccMessage> read FQueue write FQueue;
    {$ELSE}
    property Queue: TObjectList read FQueue write FQueue;
    {$ENDIF}

    function FindBySourceNode(LccMessage: TLccMessage): Integer;
  public
    property SendMessageFunc: TOnMessageEvent read FSendMessageFunc write FSendMessageFunc;

    constructor Create;
    destructor Destroy; override;
    function Add(LccMessage: TLccMessage): Boolean;
    procedure Clear;
    procedure Resend(LccMessage: TLccMessage);
    procedure Remove(LccMessage: TLccMessage);
    procedure TickTimeout;
  end;

  { TLccNode }

  TLccNode = class(TInterfacedObject)
  private
    FAliasID: Word;
    FDatagramResendQueue: TDatagramQueue;
    FDuplicateAliasDetected: Boolean;
    FGridConnect: Boolean;
    FLocalMessageStack: TList;
    FLoginTimoutCounter: Integer;
    FPermitted: Boolean;
    FProtocolACDIMfg: TProtocolACDIMfg;
    FProtocolACDIUser: TProtocolACDIUser;
    FProtocolEventConsumed: TProtocolEvents;
    FProtocolEventsProduced: TProtocolEvents;
    FProtocolMemoryConfiguration: TProtocolMemoryConfiguration;
    FProtocolMemoryInfo: TProtocolMemoryInfo;
    FProtocolMemoryOptions: TProtocolMemoryOptions;
    FProtocolSimpleNodeInfo: TProtocolSimpleNodeInfo;
    FProtocolSupportedProtocols: TProtocolSupportedProtocols;
    FProtocolMemoryConfigurationDefinitionInfo: TProtocolMemoryConfigurationDefinitionInfo;
    FSeedNodeID: TNodeID;
    FWorkerMessageDatagram: TLccMessage;
    FInitialized: Boolean;
    FNodeManager: {$IFDEF DELPHI}TComponent{$ELSE}TObject{$ENDIF};
    FSendMessageFunc: TOnMessageEvent;
    FStreamManufacturerData: TMemoryStream;        // Stream containing the Manufacturer Data stored like the User data with Fixed Offsets for read only data
                                                   // SNIP uses this structure to create a packed version of this information (null separated strings) +
                                                   // the user name and user description which it pulls out of the Configuration Stream
                                                   // Address 0 = Version
                                                   // Address 1 = Manufacturer
                                                   // Address 42 = Model
                                                   // Address 83 = Hardware Version
                                                   // Address 104 = Software Version
    FStreamCdi: TMemoryStream;                     // Stream containing the XML string for the CDI (Configuration Definition Info)
    FStreamConfig: TMemoryStream;                  // Stream containing the writable configuration memory where the Address = Offset in the stream
                                                   // and the following MUST be true
                                                   // Address 0 = User info Version number
                                                   // Address 1 = User Defined name (ACDI/SNIP)
                                                   // Address 64 = User defined description  (ACDI/SNIP)
                                                   // Address 128 = Node specific persistent data
    FStreamTractionConfig: TMemoryStream;          // Stream containing the writable configuration memory for a Traction node where the Address = Offset in the stream
    FStreamTractionFdi: TMemoryStream;             // Stream containing the XML string for the FDI (Function Definition Info)
    FWorkerMessage: TLccMessage;
    F_100msTimer: TLccTimer;

    function GetAliasIDStr: String;
    function GetNodeIDStr: String;
    procedure SetSendMessageFunc(AValue: TOnMessageEvent);
  protected
    FNodeID: TNodeID;

    property LocalMessageStack: TList read FLocalMessageStack write FLocalMessageStack;
    property NodeManager:{$IFDEF DELPHI}TComponent{$ELSE}TObject{$ENDIF} read FNodeManager write FNodeManager;
    property StreamCdi: TMemoryStream read FStreamCdi write FStreamCdi;
    property StreamConfig: TMemoryStream read FStreamConfig write FStreamConfig;
    property StreamManufacturerData: TMemoryStream read FStreamManufacturerData write FStreamManufacturerData;
    property StreamTractionFdi: TMemoryStream read FStreamTractionFdi write FStreamTractionFdi;
    property StreamTractionConfig: TMemoryStream read FStreamTractionConfig write FStreamTractionConfig;

    property WorkerMessage: TLccMessage read FWorkerMessage write FWorkerMessage;
    property WorkerMessageDatagram: TLccMessage read FWorkerMessageDatagram write FWorkerMessageDatagram;
    property _100msTimer: TLccTimer read F_100msTimer write F_100msTimer;

    // GridConnect Helpers
    property DuplicateAliasDetected: Boolean read FDuplicateAliasDetected write FDuplicateAliasDetected;
    property SeedNodeID: TNodeID read FSeedNodeID write FSeedNodeID;
    property LoginTimoutCounter: Integer read FLoginTimoutCounter write FLoginTimoutCounter;

    procedure CreateNodeID(var Seed: TNodeID);
    function FindCdiElement(TestXML, Element: string; var Offset: Integer; var ALength: Integer): Boolean;
    function LoadManufacturerDataStream(ACdi: string): Boolean;
    procedure AutoGenerateEvents;
    procedure SendDatagramAckReply(SourceMessage: TLccMessage; ReplyPending: Boolean; TimeOutValueN: Byte);
    procedure SendDatagramRejectedReply(SourceMessage: TLccMessage; Reason: Word);
    procedure SendDatagramRequiredReply(SourceMessage, ReplyLccMessage: TLccMessage);
    procedure On_100msTimer(Sender: TObject);  virtual;
    function GetCdiFile: string; virtual;
    procedure BeforeLogin; virtual;
    procedure LccLogIn(ANodeID: TNodeID); virtual;

    // GridConnect Helpers
    function GenerateID_Alias_From_Seed(var Seed: TNodeID): Word;
    procedure GenerateNewSeed(var Seed: TNodeID);
    procedure Relogin;
    procedure NotifyAndUpdateMappingChanges;

  public
    property DatagramResendQueue: TDatagramQueue read FDatagramResendQueue;
    property GridConnect: Boolean read FGridConnect;
    property NodeID: TNodeID read FNodeID;
    property NodeIDStr: String read GetNodeIDStr;
    property Initialized: Boolean read FInitialized;
    property SendMessageFunc: TOnMessageEvent read FSendMessageFunc write SetSendMessageFunc;

    property ProtocolSupportedProtocols: TProtocolSupportedProtocols read FProtocolSupportedProtocols write FProtocolSupportedProtocols;
    property ProtocolEventConsumed: TProtocolEvents read FProtocolEventConsumed write FProtocolEventConsumed;
    property ProtocolEventsProduced: TProtocolEvents read FProtocolEventsProduced write FProtocolEventsProduced;
    property ProtocolMemoryInfo: TProtocolMemoryInfo read FProtocolMemoryInfo write FProtocolMemoryInfo;
    property ProtocolMemoryOptions: TProtocolMemoryOptions read FProtocolMemoryOptions write FProtocolMemoryOptions;
    property ProtocolMemoryConfigurationDefinitionInfo: TProtocolMemoryConfigurationDefinitionInfo read FProtocolMemoryConfigurationDefinitionInfo write FProtocolMemoryConfigurationDefinitionInfo;
    property ProtocolSimpleNodeInfo: TProtocolSimpleNodeInfo read FProtocolSimpleNodeInfo write FProtocolSimpleNodeInfo;
    property ProtocolMemoryConfiguration: TProtocolMemoryConfiguration read FProtocolMemoryConfiguration write FProtocolMemoryConfiguration;
    property ProtocolACDIMfg: TProtocolACDIMfg read FProtocolACDIMfg write FProtocolACDIMfg;
    property ProtocolACDIUser: TProtocolACDIUser read FProtocolACDIUser write FProtocolACDIUser;

    // GridConnect Helpers
    property AliasID: Word read FAliasID;
    property AliasIDStr: String read GetAliasIDStr;
    property Permitted: Boolean read FPermitted;

    constructor Create(ANodeManager: {$IFDEF DELPHI}TComponent{$ELSE}TObject{$ENDIF}; CdiXML: string; GridConnectLink: Boolean); virtual;
    destructor Destroy; override;

    procedure Login(ANodeID: TNodeID); virtual;
    procedure ReleaseAlias(DelayTime_ms: Word); virtual;
    function ProcessMessage(SourceMessage: TLccMessage): Boolean; // Do not override this override the next 2
    function ProcessMessageLCC(SourceMessage: TLccMessage): Boolean; virtual;
    function ProcessMessageGridConnect(SourceMessage: TLccMessage): Boolean; virtual;
    procedure SendEvents;
    procedure SendConsumedEvents;
    procedure SendConsumerIdentify(Event: TEventID);
    procedure SendProducedEvents;
    procedure SendProducerIdentify(Event: TEventID);
  end;

  TLccNodeClass = class of TLccNode;


var
  InprocessMessageAllocated: Integer = 0;

implementation

uses
  lcc_node_manager;


{ TDatagramQueue }

procedure TDatagramQueue.Remove(LccMessage: TLccMessage);
var
  iLocalMessage: Integer;
begin
  iLocalMessage := FindBySourceNode(LccMessage);
  if iLocalMessage > -1 then
    Queue. Delete(iLocalMessage);
end;

function TDatagramQueue.Add(LccMessage: TLccMessage): Boolean;
begin
  Result := True;
  Queue.Add(LccMessage);
  LccMessage.RetryAttempts := 0;
  LccMessage.AbandonTimeout := 0;
end;

constructor TDatagramQueue.Create;
begin
  inherited Create;
  {$IFDEF DELPHI}
  Queue := TObjectList<TLccMessage>.Create;
  {$ELSE}
  Queue := TObjectList.Create;
  {$ENDIF}
  Queue.OwnsObjects := True;
end;

destructor TDatagramQueue.Destroy;
begin
  {$IFDEF FPC}
  FreeAndNil(FQueue);
  {$ELSE}
    Queue.DisposeOf;
  {$ENDIF}
  inherited Destroy;
end;

function TDatagramQueue.FindBySourceNode(LccMessage: TLccMessage): Integer;
var
  i: Integer;
  QueueAlias: Word;
  QueueNodeID: TNodeID;
begin
  Result := -1;
  i := 0;
  while i < Queue.Count do
  begin
    QueueAlias := (Queue[i] as TLccMessage).CAN.DestAlias;
    QueueNodeID := (Queue[i] as TLccMessage).DestID;
    if (QueueAlias <> 0) and (LccMessage.CAN.SourceAlias <> 0) then
    begin
      if QueueAlias = LccMessage.CAN.SourceAlias then
      begin
        Result := i;
        Break
      end;
    end else
    if not NullNodeID(QueueNodeID) and not NullNodeID(LccMessage.SourceID) then
    begin
      if EqualNodeID(QueueNodeID, LccMessage.SourceID, False) then
      begin
        Result := i;
        Break
      end;
    end;
    Inc(i)
  end;
end;

procedure TDatagramQueue.Clear;
begin
  Queue.Clear;
end;

procedure TDatagramQueue.Resend(LccMessage: TLccMessage);
var
  iLocalMessage: Integer;
  LocalMessage: TLccMessage;
begin
  iLocalMessage := FindBySourceNode(LccMessage);
  if iLocalMessage > -1 then
  begin
    LocalMessage := Queue[iLocalMessage] as TLccMessage;
    if LocalMessage.RetryAttempts < 5 then
    begin
      LocalMessage := Queue[iLocalMessage] as TLccMessage;
      SendMessageFunc(Self, LocalMessage);
      LocalMessage.RetryAttempts := LocalMessage.RetryAttempts + 1;
    end else
      {$IFDEF DWSCRIPT}
      Queue.Remove(Queue.IndexOf(LocalMessage));
      {$ELSE}
      Queue.Delete(iLocalMessage);
      {$ENDIF}
  end;
end;

procedure TDatagramQueue.TickTimeout;
var
  LocalMessage: TLccMessage;
  i: Integer;
begin
  for i := Queue.Count - 1 downto 0 do
  begin
    LocalMessage := Queue[i] as TLccMessage;
    if LocalMessage.AbandonTimeout < 6 then   // 800ms * 6
      LocalMessage.AbandonTimeout := LocalMessage.AbandonTimeout + 1
    else
      Queue.Delete(i);
  end;
end;

{TLccNode }

function TLccNode.GetNodeIDStr: String;
begin
  Result := NodeIDToString(NodeID, False);
end;

procedure TLccNode.SetSendMessageFunc(AValue: TOnMessageEvent);
begin
  FSendMessageFunc := AValue;
  ProtocolSupportedProtocols.SendMessageFunc := AValue;
  FProtocolSimpleNodeInfo.SendMessageFunc := AValue;
  ProtocolMemoryConfigurationDefinitionInfo.SendMessageFunc := AValue;
  ProtocolMemoryOptions.SendMessageFunc := AValue;
  ProtocolMemoryInfo.SendMessageFunc := AValue;
  ProtocolEventConsumed.SendMessageFunc := AValue;
  ProtocolEventsProduced.SendMessageFunc := AValue;
  DatagramResendQueue.SendMessageFunc := AValue;
end;

function TLccNode.GetAliasIDStr: String;
begin
  Result := NodeAliasToString(AliasID);
end;

function TLccNode.LoadManufacturerDataStream(ACdi: string): Boolean;
var
  AnOffset, ALength, i: Integer;
begin
  Result := False;

  StreamManufacturerData.Size := LEN_MANUFACTURER_INFO;
  for i := 0 to StreamManufacturerData.Size - 1 do
    StreamWriteByte(StreamManufacturerData, 0);

  StreamManufacturerData.Position := ADDRESS_VERSION;
  StreamWriteByte(StreamManufacturerData, 1);

  AnOffset := 0;
  ALength := 0;
  if FindCdiElement(ACdi, '<manufacturer>', AnOffset, ALength) then
  begin
    if ALength < LEN_MFG_NAME then
    begin
      StreamManufacturerData.Position := ADDRESS_MFG_NAME;
      for i := AnOffset to AnOffset + ALength - 1 do
        StreamWriteByte(StreamManufacturerData, Ord(ACdi[i]));
    end else Exit;
  end else Exit;
  if FindCdiElement(ACdi, '<model>', AnOffset, ALength) then
  begin
    if ALength < LEN_MODEL_NAME then
    begin
      StreamManufacturerData.Position := ADDRESS_MODEL_NAME;
      for i := AnOffset to AnOffset + ALength - 1 do
        StreamWriteByte(StreamManufacturerData, Ord(ACdi[i]));
    end else Exit;
  end else Exit;
  if FindCdiElement(ACdi, '<hardwareVersion>', AnOffset, ALength) then
  begin
    if ALength < LEN_HARDWARE_VERSION then
    begin
      StreamManufacturerData.Position := ADDRESS_HARDWARE_VERSION;
      for i := AnOffset to AnOffset + ALength - 1 do
        StreamWriteByte(StreamManufacturerData, Ord(ACdi[i]));
    end else Exit;
  end else Exit;
  if FindCdiElement(ACdi, '<softwareVersion>', AnOffset, ALength) then
  begin
    if ALength < LEN_SOFTWARE_VERSION then
    begin
      StreamManufacturerData.Position := ADDRESS_SOFTWARE_VERSION;
      for i := AnOffset to AnOffset + ALength - 1 do
        StreamWriteByte(StreamManufacturerData, Ord(ACdi[i]));
    end else Exit;
  end else Exit;
  Result := True;
end;

constructor TLccNode.Create(ANodeManager: {$IFDEF DELPHI}TComponent{$ELSE}TObject{$ENDIF}; CdiXML: string; GridConnectLink: Boolean);
var
  i, Counter: Integer;
begin
  inherited Create;
  FProtocolSupportedProtocols := TProtocolSupportedProtocols.Create;
  FProtocolSimpleNodeInfo := TProtocolSimpleNodeInfo.Create;
  FProtocolMemoryConfigurationDefinitionInfo := TProtocolMemoryConfigurationDefinitionInfo.Create;
  FProtocolMemoryOptions := TProtocolMemoryOptions.Create;
  FProtocolMemoryConfiguration := TProtocolMemoryConfiguration.Create;
  FProtocolMemoryInfo := TProtocolMemoryInfo.Create;
  FProtocolEventConsumed := TProtocolEvents.Create;
  FProtocolEventsProduced := TProtocolEvents.Create;

  FProtocolACDIMfg := TProtocolACDIMfg.Create;
  FProtocolACDIUser := TProtocolACDIUser.Create;
  FStreamCdi := TMemoryStream.Create;
  FStreamConfig := TMemoryStream.Create;
  FStreamManufacturerData := TMemoryStream.Create;
  FStreamTractionConfig := TMemoryStream.Create;
  FStreamTractionFdi := TMemoryStream.Create;

  FDatagramResendQueue := TDatagramQueue.Create;
  FWorkerMessageDatagram := TLccMessage.Create;
  FWorkerMessage := TLccMessage.Create;
  FNodeManager := ANodeManager;
  FGridConnect := GridConnectLink;
 // FMessageIdentificationList := TLccMessageWithNodeIdentificationList.Create;
 // FMessageDestinationsWaitingForReply := TLccNodeIdentificationObjectList.Create(False);
  FLocalMessageStack := TList.Create;

  _100msTimer := TLccTimer.Create(nil);
  _100msTimer.Enabled := False;
  _100msTimer.OnTimer := {$IFNDEF DELPHI}@{$ENDIF}On_100msTimer;
  _100msTimer.Interval := 100;

  if CdiXML = '' then
    CdiXML := GetCdiFile;

  // Setup the Cdi Stream
  StreamCdi.Size := Int64( Length(CdiXML)) + 1;   // Need the null
  i := Low(CdiXML);
  for Counter := 0 to Length(CdiXML) - 1 do       // ios/android compatible
  begin
    StreamWriteByte(StreamCdi, Ord(CdiXML[i]));
    Inc(i);
  end;
  StreamWriteByte(StreamCdi, 0);

  // Setup the Manufacturer Data Stream from the XML to allow access for ACDI and SNIP
  LoadManufacturerDataStream(CdiXML);

  // Setup the Configuration Memory Stream
  StreamConfig.Size := LEN_USER_MANUFACTURER_INFO;
  StreamConfig.Position := 0;
  StreamWriteByte(StreamConfig, USER_MFG_INFO_VERSION_ID);
  while StreamConfig.Position < StreamConfig.Size do
    StreamWriteByte(StreamConfig, 0);

  // Setup the Fdi Stream

  // Setup the Function Configuration Memory Stream
end;

procedure TLccNode.AutoGenerateEvents;
var
  i: Integer;
  TempEventID: TEventID;
begin
  TempEventID := NULL_EVENT_ID;
  if ProtocolEventConsumed.AutoGenerate.Count > 0 then
  begin
    for i := 0 to ProtocolEventConsumed.AutoGenerate.Count - 1 do
    begin
      NodeIDToEventID(NodeID, ProtocolEventConsumed.AutoGenerate.StartIndex + i, TempEventID);
      ProtocolEventConsumed.Add(TempEventID, ProtocolEventConsumed.AutoGenerate.DefaultState);
    end;
    ProtocolEventConsumed.Valid := True;
  end;

  if ProtocolEventsProduced.AutoGenerate.Count > 0 then
  begin
    for i := 0 to ProtocolEventsProduced.AutoGenerate.Count - 1 do
    begin
      NodeIDToEventID(NodeID, ProtocolEventsProduced.AutoGenerate.StartIndex + i, TempEventID);
      ProtocolEventsProduced.Add(TempEventID, ProtocolEventsProduced.AutoGenerate.DefaultState);
    end;
    ProtocolEventsProduced.Valid := True;
  end;
end;

procedure TLccNode.BeforeLogin;
begin
  ProtocolSupportedProtocols.ConfigurationDefinitionInfo := True;
  ProtocolSupportedProtocols.Datagram := True;
  ProtocolSupportedProtocols.EventExchange := True;
  ProtocolSupportedProtocols.SimpleNodeInfo := True;
  ProtocolSupportedProtocols.AbbreviatedConfigurationDefinitionInfo := True;
  ProtocolSupportedProtocols.TractionControl := True;
  ProtocolSupportedProtocols.TractionSimpleTrainNodeInfo := True;
  ProtocolSupportedProtocols.TractionFunctionDefinitionInfo := True;
  ProtocolSupportedProtocols.TractionFunctionConfiguration := True;

  ProtocolMemoryInfo.Add(MSI_CDI, True, True, True, 0, $FFFFFFFF);
  ProtocolMemoryInfo.Add(MSI_ALL, True, True, True, 0, $FFFFFFFF);
  ProtocolMemoryInfo.Add(MSI_CONFIG, True, False, True, 0, $FFFFFFFF);
  ProtocolMemoryInfo.Add(MSI_ACDI_MFG, True, True, True, 0, $FFFFFFFF);
  ProtocolMemoryInfo.Add(MSI_ACDI_USER, True, False, True, 0, $FFFFFFFF);
  ProtocolMemoryInfo.Add(MSI_TRACTION_FDI, True, True, True, 0, $FFFFFFFF);
  ProtocolMemoryInfo.Add(MSI_TRACTION_FUNCTION_CONFIG, True, False, True, 0, $FFFFFFFF);

  ProtocolMemoryOptions.WriteUnderMask := True;
  ProtocolMemoryOptions.UnAlignedReads := True;
  ProtocolMemoryOptions.UnAlignedWrites := True;
  ProtocolMemoryOptions.SupportACDIMfgRead := True;
  ProtocolMemoryOptions.SupportACDIUserRead := True;
  ProtocolMemoryOptions.SupportACDIUserWrite := True;
  ProtocolMemoryOptions.WriteLenOneByte := True;
  ProtocolMemoryOptions.WriteLenTwoBytes := True;
  ProtocolMemoryOptions.WriteLenFourBytes := True;
  ProtocolMemoryOptions.WriteLenSixyFourBytes := True;
  ProtocolMemoryOptions.WriteArbitraryBytes := True;
  ProtocolMemoryOptions.WriteStream := False;
  ProtocolMemoryOptions.HighSpace := MSI_CDI;
  ProtocolMemoryOptions.LowSpace := MSI_TRACTION_FUNCTION_CONFIG;

  // Create a few events for fun
  ProtocolEventConsumed.AutoGenerate.Count := 5;
  ProtocolEventConsumed.AutoGenerate.StartIndex := 0;
  ProtocolEventsProduced.AutoGenerate.Count := 5;
  ProtocolEventsProduced.AutoGenerate.StartIndex := 0;
end;

procedure TLccNode.LccLogIn(ANodeID: TNodeID);
begin
  BeforeLogin;
  if NullNodeID(ANodeID) then
    CreateNodeID(ANodeID);  // This should only be true if not GridConnect and the NodeID was not set
  FNodeID := ANodeID;
  (NodeManager as INodeManagerCallbacks).DoNodeIDChanged(Self);
  FInitialized := True;

  // Send Initialization Complete
  WorkerMessage.LoadInitializationComplete(NodeID, FAliasID);
  SendMessageFunc(Self, WorkerMessage);
  (NodeManager as INodeManagerCallbacks).DoInitializationComplete(Self);


  AutoGenerateEvents;
  SendEvents;
  (NodeManager as INodeManagerCallbacks).DoLogInNode(Self);
end;

function TLccNode.ProcessMessageLCC(SourceMessage: TLccMessage): Boolean;

var
  TestNodeID: TNodeID;
  Temp: TEventID;
  AddressSpace, OperationType: Byte;
begin

  // By the time a messages drops into this method it is a fully qualified OpenLCB
  // message.  Any CAN messages that are sent as multi frames have been combined
  // into a full OpenLCB message.
  // On GridConnect all messages have the source NodeID mapped and on messages destined
  // for this node (DestID/DestAlias) the full NodeID has been filled in.  There is an
  // attempt to fill in the DestID for messages that are not for this node but
  // it can't be guarenteed that field will be valid.  This should not be of concern
  // as we should not be doing anything with those messages anyway other than possibly snooping

  Result := False;

  if not Initialized then
  begin
    Result := True; // Handled
    Exit;
  end;

  TestNodeID[0] := 0;
  TestNodeID[1] := 0;


  // Guarenteed to have Mappings before I ever get here

  // First look for a duplicate NodeID
  if EqualNodeID(NodeID, SourceMessage.SourceID, False) then
  begin
    // Think I am suppose to send a duplicate Node ID PCER or something here....
    Result := True; // Handled
    FInitialized := False;
    Exit;
  end;

  // Next look to see if it is an addressed message and if not for use just exit


  if SourceMessage.HasDestination then
  begin
    if not EqualNode(NodeID,  AliasID, SourceMessage.DestID, SourceMessage.CAN.DestAlias, True) then
      Exit;
  end;

  case SourceMessage.MTI of
    MTI_OPTIONAL_INTERACTION_REJECTED :
        begin
          (NodeManager as INodeManagerCallbacks).DoOptionalInteractionRejected(Self, SourceMessage);
        end;

    // *************************************************************************
    // *************************************************************************
    MTI_VERIFY_NODE_ID_NUMBER      :
        begin
          if SourceMessage.DataCount = 6 then
          begin
            SourceMessage.ExtractDataBytesAsNodeID(0, TestNodeID);
            if EqualNodeID(TestNodeID, NodeID, False) then
            begin
              WorkerMessage.LoadVerifiedNodeID(NodeID, FAliasID);
              SendMessageFunc(Self, WorkerMessage);
            end
          end else
          begin
            WorkerMessage.LoadVerifiedNodeID(NodeID, FAliasID);
            SendMessageFunc(Self, WorkerMessage);
          end;
        end;
    MTI_VERIFY_NODE_ID_NUMBER_DEST :
        begin
          WorkerMessage.LoadVerifiedNodeID(NodeID, FAliasID);
          SendMessageFunc(Self, WorkerMessage);
        end;
    MTI_VERIFIED_NODE_ID_NUMBER :
        begin
          (NodeManager as INodeManagerCallbacks).DoVerifiedNodeID(Self, SourceMessage, SourceMessage.SourceID);
        end;

    // *************************************************************************
    // *************************************************************************
    MTI_SIMPLE_NODE_INFO_REQUEST :
        begin
          WorkerMessage.LoadSimpleNodeIdentInfoReply(NodeID, FAliasID, SourceMessage.SourceID, SourceMessage.CAN.SourceAlias, ProtocolSimpleNodeInfo.PackedFormat(StreamManufacturerData, StreamConfig));
          SendMessageFunc(Self, WorkerMessage);
        end;
    MTI_SIMPLE_NODE_INFO_REPLY :
        begin
          (NodeManager as INodeManagerCallbacks).DoSimpleNodeIdentReply(Self, SourceMessage);
        end;

    // *************************************************************************
    // *************************************************************************
    MTI_PROTOCOL_SUPPORT_INQUIRY :
        begin
          WorkerMessage.LoadProtocolIdentifyReply(NodeID, FAliasID, SourceMessage.SourceID, SourceMessage.CAN.SourceAlias, ProtocolSupportedProtocols.EncodeFlags);
          SendMessageFunc(Self, WorkerMessage);
        end;
    MTI_PROTOCOL_SUPPORT_REPLY :
        begin
          (NodeManager as INodeManagerCallbacks).DoProtocolIdentifyReply(Self, SourceMessage);
        end;

    // *************************************************************************
    // Producer/Consumer tell me what events do you care about (for routers, getting mass
    // results for the state of the layout
    // *************************************************************************
    MTI_EVENTS_IDENTIFY :
        begin
          SendConsumedEvents;
          SendProducedEvents;
        end;
    MTI_EVENTS_IDENTIFY_DEST :
        begin
          SendConsumedEvents;  // already known the destination is us
          SendProducedEvents;
        end;

    // *************************************************************************
    // General Producer/Consumer Queries
    // *************************************************************************
    MTI_PRODUCER_IDENDIFY : SendProducerIdentify(SourceMessage.ExtractDataBytesAsEventID(0));
    MTI_CONSUMER_IDENTIFY : SendConsumerIdentify(SourceMessage.ExtractDataBytesAsEventID(0));

    // *************************************************************************
     // This block of messages is if we sent at "Producer" or "Consumer" Identify
     // and these are the results coming back... I am not sure what "Consumer" Identify
     // needs different states as the replying node is not in control of the state only
     // the "Producer" is in control
     // *************************************************************************
     MTI_CONSUMER_IDENTIFIED_CLEAR :
        begin
          Temp := SourceMessage.ExtractDataBytesAsEventID(0);
          (NodeManager as INodeManagerCallbacks).DoConsumerIdentified(Self, SourceMessage, Temp, evs_InValid);
        end;
     MTI_CONSUMER_IDENTIFIED_SET :
        begin
         Temp := SourceMessage.ExtractDataBytesAsEventID(0);
          (NodeManager as INodeManagerCallbacks).DoConsumerIdentified(Self, SourceMessage, Temp, evs_Valid);
        end;
     MTI_CONSUMER_IDENTIFIED_UNKNOWN :
        begin
          Temp := SourceMessage.ExtractDataBytesAsEventID(0);
          (NodeManager as INodeManagerCallbacks).DoConsumerIdentified(Self, SourceMessage, Temp, evs_Unknown);
        end;
     MTI_PRODUCER_IDENTIFIED_CLEAR :
        begin
          Temp := SourceMessage.ExtractDataBytesAsEventID(0);
          (NodeManager as INodeManagerCallbacks).DoProducerIdentified(Self, SourceMessage, Temp, evs_InValid);
        end;
     MTI_PRODUCER_IDENTIFIED_SET :
        begin
          Temp := SourceMessage.ExtractDataBytesAsEventID(0);
          (NodeManager as INodeManagerCallbacks).DoProducerIdentified(Self, SourceMessage, Temp, evs_Valid);
        end;
     MTI_PRODUCER_IDENTIFIED_UNKNOWN :
        begin
          Temp := SourceMessage.ExtractDataBytesAsEventID(0);
          (NodeManager as INodeManagerCallbacks).DoProducerIdentified(Self, SourceMessage, Temp, evs_Unknown);
        end;

    // *************************************************************************
    // Datagram Messages
    // *************************************************************************
     MTI_DATAGRAM_REJECTED_REPLY :
       begin
         DatagramResendQueue.Resend(SourceMessage);
       end;
     MTI_DATAGRAM_OK_REPLY :
       begin
         DatagramResendQueue.Remove(SourceMessage);
       end;
     MTI_DATAGRAM :
       begin
         case SourceMessage.DataArray[0] of
           DATAGRAM_PROTOCOL_LOGREQUEST : {0x01}  // Makes the Python Script Happy
             begin
               SendDatagramAckReply(SourceMessage, False, 0);
             end;
           DATAGRAM_PROTOCOL_CONFIGURATION :     {0x20}
             begin
               AddressSpace := 0;

               // Figure out where the Memory space to work on is located, encoded in the header or in the first databyte slot.
               case SourceMessage.DataArray[1] and $03 of
                 MCP_NONE          : AddressSpace := SourceMessage.DataArray[6];
                 MCP_CDI           : AddressSpace := MSI_CDI;
                 MCP_ALL           : AddressSpace := MSI_ALL;
                 MCP_CONFIGURATION : AddressSpace := MSI_CONFIG;
               end;

               case SourceMessage.DataArray[1] and $F0 of
                 MCP_WRITE :
                   begin
                     case AddressSpace of
                       MSI_CDI       : begin end; // Can't write to the CDI
                       MSI_ALL       : begin end; // Can't write to the program area
                       MSI_CONFIG    :            // Needs access to the Configuration Memory Information
                         begin
                           SendDatagramAckReply(SourceMessage, False, 0);     // We will be sending a Write Reply
                           ProtocolMemoryConfiguration.DatagramWriteRequest(SourceMessage, StreamConfig);
                         end;
                       MSI_ACDI_MFG  : begin end; // Can't write to the Manufacturers area
                       MSI_ACDI_USER :            // Needs access to the Configuration Memory Information
                         begin
                           SendDatagramAckReply(SourceMessage, False, 0);     // We will be sending a Write Reply
                           ProtocolACDIUser.DatagramWriteRequest(SourceMessage, StreamConfig);
                         end;
                       MSI_TRACTION_FDI       : begin end; // Can't write to the FDI area
                       MSI_TRACTION_FUNCTION_CONFIG :
                         begin
                           SendDatagramAckReply(SourceMessage, False, 0);     // We will be sending a Write Reply
                           ProtocolMemoryConfiguration.DatagramWriteRequest(SourceMessage, StreamTractionConfig);
                         end;
                     end;
                   end;
                 MCP_READ :
                   begin
                     case AddressSpace of
                       MSI_CDI :
                         begin
                           WorkerMessage.LoadDatagram(NodeID, FAliasID, SourceMessage.SourceID, SourceMessage.CAN.SourceAlias);
                           ProtocolMemoryConfigurationDefinitionInfo.DatagramReadRequest(SourceMessage, WorkerMessage, StreamCdi);
                           SendDatagramRequiredReply(SourceMessage, WorkerMessage);
                         end;
                       MSI_ALL       :
                           begin  // Can't read from the program area
                             SendDatagramAckReply(SourceMessage, False, 0);
                           end;
                       MSI_CONFIG :
                         begin
                           WorkerMessage.LoadDatagram(NodeID, FAliasID, SourceMessage.SourceID, SourceMessage.CAN.SourceAlias);
                           ProtocolMemoryConfiguration.DatagramReadRequest(SourceMessage, WorkerMessage, StreamConfig);
                           SendDatagramRequiredReply(SourceMessage, WorkerMessage);
                         end;
                       MSI_ACDI_MFG :
                         begin
                           WorkerMessage.LoadDatagram(NodeID, FAliasID, SourceMessage.SourceID, SourceMessage.CAN.SourceAlias);
                           ProtocolACDIMfg.DatagramReadRequest(SourceMessage, WorkerMessage, StreamManufacturerData);
                           SendDatagramRequiredReply(SourceMessage, WorkerMessage);
                         end;
                       MSI_ACDI_USER :
                         begin
                           WorkerMessage.LoadDatagram(NodeID, FAliasID, SourceMessage.SourceID, SourceMessage.CAN.SourceAlias);
                           ProtocolACDIUser.DatagramReadRequest(SourceMessage, WorkerMessage, StreamConfig);
                           SendDatagramRequiredReply(SourceMessage, WorkerMessage);
                         end;
                       MSI_TRACTION_FDI :
                         begin
                           WorkerMessage.LoadDatagram(NodeID, FAliasID, SourceMessage.SourceID, SourceMessage.CAN.SourceAlias);
                           ProtocolMemoryConfigurationDefinitionInfo.DatagramReadRequest(SourceMessage, WorkerMessage, StreamTractionFdi);
                           SendDatagramRequiredReply(SourceMessage, WorkerMessage);
                         end;
                       MSI_TRACTION_FUNCTION_CONFIG :
                         begin
                           WorkerMessage.LoadDatagram(NodeID, FAliasID, SourceMessage.SourceID, SourceMessage.CAN.SourceAlias);
                           ProtocolMemoryConfiguration.DatagramReadRequest(SourceMessage, WorkerMessage, StreamTractionConfig);
                           SendDatagramRequiredReply(SourceMessage, WorkerMessage);
                         end;
                     end;
                   end;
                 MCP_WRITE_STREAM :
                   begin
                   end;
                 MCP_READ_STREAM :
                   begin
                   end;
                 MCP_OPERATION :
                   begin
                     OperationType := SourceMessage.DataArray[1];
                     case OperationType of
                       MCP_OP_GET_CONFIG :
                           begin
                             WorkerMessage.LoadDatagram(NodeID, FAliasID, SourceMessage.SourceID,
                                                        SourceMessage.CAN.SourceAlias);
                             ProtocolMemoryOptions.LoadReply(WorkerMessage);
                             SendDatagramRequiredReply(SourceMessage, WorkerMessage);
                           end;
                       MCP_OP_GET_ADD_SPACE_INFO :
                           begin
                             WorkerMessage.LoadDatagram(NodeID, FAliasID, SourceMessage.SourceID,
                                                        SourceMessage.CAN.SourceAlias);
                             ProtocolMemoryInfo.LoadReply(SourceMessage, WorkerMessage);
                             SendDatagramRequiredReply(SourceMessage, WorkerMessage);
                           end;
                       MCP_OP_LOCK :
                           begin
                           end;
                       MCP_OP_GET_UNIQUEID :
                           begin
                           end;
                       MCP_OP_FREEZE :
                           begin
                           end;
                       MCP_OP_INDICATE :
                           begin
                           end;
                       MCP_OP_RESETS :
                           begin
                           end;
                     end // case
                   end;
               end
             end
         else begin {case else}
             // Unknown Datagram Type
             WorkerMessage.LoadDatagramRejected(NodeID, FAliasID, SourceMessage.SourceID, SourceMessage.CAN.SourceAlias, ERROR_PERMANENT_NOT_IMPLEMENTED or ERROR_TYPE);
             SendMessageFunc(Self, WorkerMessage);
           end;
         end;  // case
       end;
  else begin
      if SourceMessage.HasDestination then
      begin
        WorkerMessage.LoadOptionalInteractionRejected(NodeID, FAliasID, SourceMessage.SourceID, SourceMessage.CAN.SourceAlias, ERROR_PERMANENT_NOT_IMPLEMENTED or ERROR_MTI, SourceMessage.MTI);
        SendMessageFunc(Self, WorkerMessage)
      end;
    end;
  end; // case
end;

function TLccNode.ProcessMessageGridConnect(SourceMessage: TLccMessage): Boolean;

var
  TestNodeID: TNodeID;
  ANodeIdentificationObjectList: TLccNodeIdentificationObjectList;
  LocalNodeIdentificationObject: TLccNodeIdentificationObject;
  i: Integer;
  AliasMapping: TLccAliasMapping;
begin
  Result := False;
  TestNodeID[0] := 0;
  TestNodeID[1] := 0;

  // Alias Allocation, duplicate checking after allocation**********************
  // Check for a message with the Alias equal to our own.
  if (AliasID <> 0) and (SourceMessage.CAN.SourceAlias = AliasID) then
  begin
    // Check if it is a Check ID message for a node trying to use our Alias and if so tell them no.
    if ((SourceMessage.CAN.MTI and $0F000000) >= MTI_CAN_CID6) and ((SourceMessage.CAN.MTI and $0F000000) <= MTI_CAN_CID0) then
    begin
      WorkerMessage.LoadRID(NodeID, AliasID);                   // sorry charlie this is mine
      SendMessageFunc(Self, WorkerMessage);
      Result := True;
    end else
    if Permitted then
    begin
      // Another node used our Alias, stop using this Alias, log out and allocate a new node and relog in
      ReleaseAlias(100);
      Relogin;
      Result := True;   // Logout covers any LccNode logoffs, so don't call ancester Process Message
    end
  end;
  // END: Alias Allocation, duplicate checking after allocation******************


  if not Permitted then
  begin
    // We are still trying to allocate a new Alias, someone else is using this alias
    if SourceMessage.CAN.SourceAlias = AliasID then
      DuplicateAliasDetected := True;
  end else
  begin  // Normal message loop once successfully allocating an Alias
    if SourceMessage.IsCAN then
    begin
      case SourceMessage.CAN.MTI of
        MTI_CAN_AME :          // Asking us for an Alias Map Enquiry
          begin
            if SourceMessage.DataCount = 6 then
            begin
              SourceMessage.ExtractDataBytesAsNodeID(0, TestNodeID);
              if EqualNodeID(TestNodeID, NodeID, False) then
              begin
                WorkerMessage.LoadAMD(NodeID, AliasID);
                SendMessageFunc(Self, WorkerMessage);
              end
            end else
            begin
              WorkerMessage.LoadAMD(NodeID, AliasID);
              SendMessageFunc(Self, WorkerMessage);
            end;
          end;
      end;
      Result := True;
    end else
    begin
      if not Result then
      begin
        if not Result then
        begin
          ANodeIdentificationObjectList := SourceMessage.ExtractNodeIdentifications(False);
          for i := 0 to ANodeIdentificationObjectList.Count - 1 do
          begin
            LocalNodeIdentificationObject := ANodeIdentificationObjectList[i];

            if LocalNodeIdentificationObject.Active then
            begin
              if not LocalNodeIdentificationObject.Valid then
              begin
                if LocalNodeIdentificationObject.Alias > 0 then
                  AliasMapping := AliasServer.FindMapping(LocalNodeIdentificationObject.Alias)
                else
                  AliasMapping := AliasServer.FindMapping(LocalNodeIdentificationObject.NodeID);

                if not Assigned(AliasMapping) then
                begin
                  {$IFDEF WriteLnDebug}
                  AliasServer.WriteMapping('Cound not find Mapping at Message Position: ' +
                    IntToStr(i) +
                    ' - Alias' +
                    IntToHex(LocalNodeIdentificationObject.Alias, 4) + ' ID: ' +
                    NodeIDToString(LocalNodeIdentificationObject.NodeID, True),
                    nil);
                  {$ENDIF}

                  if LocalNodeIdentificationObject.Alias > 0 then
                  begin
                    WorkerMessage.LoadVerifyNodeIDAddressed(NodeID, AliasID, LocalNodeIdentificationObject.NodeID, LocalNodeIdentificationObject.Alias, NULL_NODE_ID);
                    SendMessageFunc(Self, WorkerMessage);
                  end else
                  if not NullNodeID(LocalNodeIdentificationObject.NodeID) then
                  begin
                    WorkerMessage.LoadVerifyNodeID(NodeID, AliasID, LocalNodeIdentificationObject.NodeID);
                    SendMessageFunc(Self, WorkerMessage);
                  end;

                  // wait for it to return and complete the mapping
                  while not Assigned(AliasMapping) do
                  begin
                    AliasMapping := AliasServer.FindMapping(LocalNodeIdentificationObject.Alias);
                    Sleep(5);
                  end;
                end;
              end;
            end;
          end;

          ProcessMessageLCC(SourceMessage);
        end
      end
    end;
  end;
end;

function TLccNode.GenerateID_Alias_From_Seed(var Seed: TNodeID): Word;
begin
  Result := (Seed[0] xor Seed[1] xor (Seed[0] shr 12) xor (Seed[1] shr 12)) and $00000FFF;
end;

procedure TLccNode.GenerateNewSeed(var Seed: TNodeID);
var
  temp1,              // Upper 24 Bits of temp 48 bit number
  temp2: DWORD;       // Lower 24 Bits of temp 48 Bit number
begin
  temp1 := ((Seed[1] shl 9) or ((Seed[0] shr 15) and $000001FF)) and $00FFFFFF;   // x(i+1)(2^9 + 1)*x(i) + C  = 2^9 * x(i) + x(i) + C
  temp2 := (Seed[0] shl 9) and $00FFFFFF;                                                                  // Calculate 2^9 * x

  Seed[0] := Seed[0] + temp2 + $7A4BA9;   // Now y = 2^9 * x so all we have left is x(i+1) = y + x + c
  Seed[1] := Seed[1] + temp1 + $1B0CA3;

  Seed[1] := (Seed[1] and $00FFFFFF) or (Seed[0] and $FF000000) shr 24;   // Handle the carries of the lower 24 bits into the upper
  Seed[0] := Seed[0] and $00FFFFFF;
end;

procedure TLccNode.Relogin;
var
  Temp: TNodeID;
begin
  // Typically due to an alias conflict to create a new one
  Temp := FSeedNodeID;
  GenerateNewSeed(Temp);
  FSeedNodeID := Temp;
  FAliasID := GenerateID_Alias_From_Seed(Temp);
  WorkerMessage.LoadCID(NodeID, AliasID, 0);
  SendMessageFunc(Self, WorkerMessage);
  WorkerMessage.LoadCID(NodeID, AliasID, 1);
  SendMessageFunc(Self, WorkerMessage);
  WorkerMessage.LoadCID(NodeID, AliasID, 2);
  SendMessageFunc(Self, WorkerMessage);
  WorkerMessage.LoadCID(NodeID, AliasID, 3);
  SendMessageFunc(Self, WorkerMessage);

  LoginTimoutCounter := 0;
  _100msTimer.Enabled := True;  //  Next state is in the event handler to see if anyone objects tor our Alias
end;

procedure TLccNode.NotifyAndUpdateMappingChanges;
var
  LocalMapping: TLccAliasMapping;
  MappingList: TList;
  i: Integer;
begin
  MappingList := AliasServer.MappingList.LockList;
  try
    for i := MappingList.Count - 1 downto 0 do
    begin
      LocalMapping := TLccAliasMapping(MappingList[i]);
      if LocalMapping.MarkedForInsertion then
      begin
        (NodeManager as INodeManagerCallbacks).DoAliasMappingChange(Self, LocalMapping, True);
        LocalMapping.MarkedForInsertion := False;  // Handled
      end;
      if LocalMapping.MarkedForDeletion then
      begin
        (NodeManager as INodeManagerCallbacks).DoAliasMappingChange(Self, LocalMapping, False);
        LocalMapping.Free;
        MappingList.Delete(i);
      end;
    end;

  finally
    AliasServer.MappingList.UnlockList;
  end;

//  (NodeManager as INodeManagerCallbacks).DoTrainRegisteringChange(Self, LocalTrainObject, False);
end;

procedure TLccNode.CreateNodeID(var Seed: TNodeID);
begin
  Seed[1] := StrToInt('0x020112');
  Seed[0] := Random($FFFFFF);
end;

destructor TLccNode.Destroy;
begin
  _100msTimer.Enabled := False;

  NotifyAndUpdateMappingChanges; // fire any eventfor Mapping changes are are marked for deletion in the Logout method

  if GridConnect then
  begin
    if AliasID <> 0 then
      ReleaseAlias(100);
     (NodeManager as INodeManagerCallbacks).DoAliasIDChanged(Self);
  end;

  FNodeID[0] := 0;
  FNodeID[1] := 0;
  (NodeManager as INodeManagerCallbacks).DoNodeIDChanged(Self);

  (NodeManager as INodeManagerCallbacks).DoDestroyLccNode(Self);
  _100msTimer.Free;

  FreeAndNil(FProtocolSupportedProtocols);
  FreeAndNil(FProtocolSimpleNodeInfo);
  FreeAndNil(FProtocolEventConsumed);
  FreeAndNil(FProtocolEventsProduced);
  FreeAndNil(FProtocolMemoryOptions);
  FreeAndNil(FProtocolMemoryInfo);
  FreeAndNil(FProtocolACDIMfg);
  FreeAndNil(FProtocolACDIUser);
  FreeAndNil(FProtocolMemoryConfigurationDefinitionInfo);
  FreeAndNil(FDatagramResendQueue);
  FreeAndNil(FWorkerMessageDatagram);
  FreeAndNil(FWorkerMessage);
  FreeAndNil(FStreamCdi);
  FreeAndNil(FStreamConfig);
  FreeAndNil(FStreamManufacturerData);
  FreeAndNil(FStreamTractionConfig);
  FreeAndNil(FStreamTractionFdi);
  FreeAndNil(FLocalMessageStack);
  FProtocolMemoryConfiguration.Free;
  inherited;
end;

function TLccNode.FindCdiElement(TestXML, Element: string; var Offset: Integer; var ALength: Integer): Boolean;
var
  OffsetEnd: Integer;
begin
  Result := False;
  TestXML := LowerCase(TestXML);
  Element := LowerCase(Element);
  Offset := Pos(Element, TestXML);
  if Offset > -1 then
  begin
    Inc(Offset, Length(Element));
    Element := StringReplace(Element, '<', '</', [rfReplaceAll]);
    OffsetEnd := Pos(Element, TestXML);
    if (OffsetEnd > -1) and (OffsetEnd > Offset) then
    begin
      ALength := OffsetEnd - Offset;
      Result := True;
      OffsetEnd := Low(TestXML);  // The "Low" would not work in the following if statement directly in Delphi
      if OffsetEnd = 0 then   // Mobile
        Dec(Offset, 1);
    end else
    Exit;
  end
end;

function TLccNode.GetCdiFile: string;
begin
  Result := CDI_XML;
end;

procedure TLccNode.Login(ANodeID: TNodeID);
var
  Temp: TNodeID;
begin
  if GridConnect then
  begin
    {$IFDEF WriteLnDebug} WriteLn('Node Logging In'); {$ENDIF}
    BeforeLogin;
    if NullNodeID(ANodeID) then
      CreateNodeID(ANodeID);
    SeedNodeID := ANodeID;
    Temp := FSeedNodeID;
    FAliasID := GenerateID_Alias_From_Seed(Temp);
    (NodeManager as INodeManagerCallbacks).DoNodeIDChanged(Self);
    FNodeID := ANodeID;

    WorkerMessage.LoadCID(NodeID, AliasID, 0);
    SendMessageFunc(Self, WorkerMessage);
    WorkerMessage.LoadCID(NodeID, AliasID, 1);
    SendMessageFunc(Self, WorkerMessage);
    WorkerMessage.LoadCID(NodeID, AliasID, 2);
    SendMessageFunc(Self, WorkerMessage);
    WorkerMessage.LoadCID(NodeID, AliasID, 3);
    SendMessageFunc(Self, WorkerMessage);

    LoginTimoutCounter := 0;
    _100msTimer.Enabled := True;  //  Next state is in the event handler to see if anyone objects tor our Alias
  end else
    LccLogIn(ANodeID);
end;

procedure TLccNode.ReleaseAlias(DelayTime_ms: Word);
begin
  if GridConnect then
  begin
    WorkerMessage.LoadAMR(NodeID, AliasID);
    SendMessageFunc(Self, WorkerMessage);
    // Wait for the message to get sent on the hardware layers.  Testing this happens is complicated
    // This assumes they are all running in separate thread and they keep running
    Sleep(DelayTime_ms);
    FPermitted := False;
    (NodeManager as INodeManagerCallbacks).DoAliasReset(Self);
    AliasServer.MarkForRemovalByAlias(AliasID);
    FAliasID := 0;
  end;
  DatagramResendQueue.Clear;
  FInitialized := False;
  _100msTimer.Enabled := False;
end;

procedure TLccNode.On_100msTimer(Sender: TObject);
var
  Temp: TNodeID;
begin
  if GridConnect then
  begin
    if not Permitted then
    begin
      Inc(FLoginTimoutCounter);
       // Did any node object to this Alias through ProcessMessage?
      if DuplicateAliasDetected then
      begin
        {$IFDEF WriteLnDebug} WriteLn('Node Duplicate ID'); {$ENDIF}
        DuplicateAliasDetected := False;  // Reset
        Temp := FSeedNodeID;
        GenerateNewSeed(Temp);
        FSeedNodeID := Temp;
        FAliasID := GenerateID_Alias_From_Seed(Temp);
        WorkerMessage.LoadCID(NodeID, AliasID, 0);
        SendMessageFunc(Self, WorkerMessage);
        WorkerMessage.LoadCID(NodeID, AliasID, 1);
        SendMessageFunc(Self, WorkerMessage);
        WorkerMessage.LoadCID(NodeID, AliasID, 2);
        SendMessageFunc(Self, WorkerMessage);
        WorkerMessage.LoadCID(NodeID, AliasID, 3);
        SendMessageFunc(Self, WorkerMessage);
        LoginTimoutCounter := 0;
      end else
      begin
        if LoginTimoutCounter > 7 then
        begin
          {$IFDEF WriteLnDebug} WriteLn('Node Logged In'); {$ENDIF}
          FPermitted := True;
          WorkerMessage.LoadRID(NodeID, AliasID);
          SendMessageFunc(Self, WorkerMessage);
          WorkerMessage.LoadAMD(NodeID, AliasID);
          SendMessageFunc(Self, WorkerMessage);
          (NodeManager as INodeManagerCallbacks).DoAliasIDChanged(Self);
          LccLogIn(NodeID);
        end;
      end
    end else  // Is Permitted
    begin
      DatagramResendQueue.TickTimeout;
      NotifyAndUpdateMappingChanges;
    end;
  end else  // Is not GridConnect
  begin
    DatagramResendQueue.TickTimeout;
  end;
end;

function TLccNode.ProcessMessage(SourceMessage: TLccMessage): Boolean;
begin
  if GridConnect then
    Result := ProcessMessageGridConnect(SourceMessage)   // When necessary ProcessMessageGridConnect drops the message into ProcessMessageLCC
  else
    Result := ProcessMessageLCC(SourceMessage);
end;

procedure TLccNode.SendDatagramAckReply(SourceMessage: TLccMessage; ReplyPending: Boolean; TimeOutValueN: Byte);
begin
  // Only Ack if we accept the datagram
  WorkerMessageDatagram.LoadDatagramAck(NodeID, FAliasID,
                                        SourceMessage.SourceID, SourceMessage.CAN.SourceAlias,
                                        True, ReplyPending, TimeOutValueN);
  SendMessageFunc(Self, WorkerMessageDatagram);
end;

procedure TLccNode.SendConsumedEvents;
var
  i: Integer;
  Temp: TEventID;
begin
  for i := 0 to ProtocolEventConsumed.Count - 1 do
  begin
    Temp := ProtocolEventConsumed.Event[i].ID;
    WorkerMessage.LoadConsumerIdentified(NodeID, FAliasID, Temp, ProtocolEventConsumed.Event[i].State);
    SendMessageFunc(Self, WorkerMessage);
  end;
end;

procedure TLccNode.SendConsumerIdentify(Event: TEventID);
var
  EventObj: TLccEvent;
  Temp: TEventID;
begin
  EventObj := ProtocolEventConsumed.Supports(Event);
  if Assigned(EventObj) then
  begin
    Temp := EventObj.ID;
    WorkerMessage.LoadConsumerIdentified(NodeID, FAliasID, Temp, EventObj.State);
    SendMessageFunc(Self, WorkerMessage);
  end;
end;

procedure TLccNode.SendDatagramRejectedReply(SourceMessage: TLccMessage; Reason: Word);
begin
  WorkerMessageDatagram.LoadDatagramRejected(NodeID, FAliasID,
                                             SourceMessage.SourceID, SourceMessage.CAN.SourceAlias,
                                             Reason);
  SendMessageFunc(Self, WorkerMessageDatagram);
end;

procedure TLccNode.SendDatagramRequiredReply(SourceMessage, ReplyLccMessage: TLccMessage);
begin
  if DatagramResendQueue.Add(ReplyLccMessage.Clone) then     // Waiting for an ACK
  begin
    SendDatagramAckReply(SourceMessage, False, 0);   // We will be sending a Read Reply
    SendMessageFunc(Self, ReplyLccMessage);
  end else
    SendDatagramRejectedReply(SourceMessage, ERROR_TEMPORARY_BUFFER_UNAVAILABLE)
end;

procedure TLccNode.SendEvents;
begin
  SendConsumedEvents;
  SendProducedEvents;
end;

procedure TLccNode.SendProducedEvents;
var
  i: Integer;
  Temp: TEventID;
begin
  for i := 0 to ProtocolEventsProduced.Count - 1 do
  begin
    Temp := ProtocolEventsProduced.Event[i].ID;
    WorkerMessage.LoadProducerIdentified(NodeID, FAliasID, Temp, ProtocolEventsProduced.Event[i].State);
    SendMessageFunc(Self, WorkerMessage);
  end;
end;

procedure TLccNode.SendProducerIdentify(Event: TEventID);
var
  EventObj: TLccEvent;
  Temp: TEventID;
begin
  EventObj := ProtocolEventsProduced.Supports(Event);
  if Assigned(EventObj) then
  begin
    Temp := EventObj.ID;
    WorkerMessage.LoadProducerIdentified(NodeID, FAliasID, Temp, EventObj.State);
    SendMessageFunc(Self, WorkerMessage);
  end;
end;


initialization
  Randomize;

finalization

end.


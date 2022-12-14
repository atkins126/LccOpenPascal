unit TrainCommanderUnit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ComCtrls, ExtCtrls,
  StdCtrls,
  lcc_ethernet_server,
  lcc_defines,
  lcc_node,
  lcc_node_manager,
  lcc_ethernet_client,
  lcc_node_messages,
  lcc_node_commandstation,
  lcc_node_controller,
  lcc_node_train,
  lcc_comport,
  LazSynaSer,
 // lcc_ethernet_http,
  lcc_ethernet_websocket,
  lcc_common_classes,
  lcc_ethernet_common,
  servervisualunit,
  lcc_alias_server,
  lcc_train_server,
  lcc_xmlutilities;

type

  { TFormTrainCommander }

  TFormTrainCommander = class(TForm)
    ButtonHTTPServer: TButton;
    ButtonWebserverConnect: TButton;
    ButtonManualConnectComPort: TButton;
    ButtonTrainsClear: TButton;
    ButtonClear: TButton;
    ButtonEthernetConnect: TButton;
    CheckBox1: TCheckBox;
    CheckBoxDetailedLog: TCheckBox;
    CheckBoxLogMessages: TCheckBox;
    CheckBoxLoopBackIP: TCheckBox;
    CheckBoxAutoConnect: TCheckBox;
    ComboBoxComPorts: TComboBox;
    ImageListMain: TImageList;
    LabelNodeID: TLabel;
    LabelAliasID: TLabel;
    LabelAliasIDCaption: TLabel;
    LabelNodeIDCaption: TLabel;
    ListviewConnections: TListView;
    MemoComPort: TMemo;
    MemoLog: TMemo;
    PanelTrainsHeader: TPanel;
    PanelTrains: TPanel;
    PanelConnections: TPanel;
    PanelDetails: TPanel;
    SplitterConnections1: TSplitter;
    SplitterTrains: TSplitter;
    SplitterConnections: TSplitter;
    StatusBarMain: TStatusBar;
    ToggleBoxServerForm: TToggleBox;
    TreeViewTrains: TTreeView;
    procedure ButtonHTTPServerClick(Sender: TObject);
    procedure ButtonWebserverConnectClick(Sender: TObject);
    procedure ButtonManualConnectComPortClick(Sender: TObject);
    procedure ButtonClearClick(Sender: TObject);
    procedure ButtonEthernetConnectClick(Sender: TObject);
    procedure ButtonTrainsReleaseAliasClick(Sender: TObject);
    procedure CheckBox1Change(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure ToggleBoxServerFormChange(Sender: TObject);
  private
    FCommandStationNode: TLccCommandStationNode;
    FComPort: TLccComPort;
 //   FLccHTTPServer: TLccHTTPServer;
 //   FLccWebsocketServer: TLccWebsocketServer;
    FNodeManager: TLccNodeManager;
    FWorkerMessage: TLccMessage;
    FLccServer: TLccEthernetServer;
  protected
    property WorkerMessage: TLccMessage read FWorkerMessage write FWorkerMessage;

    function ConnectServer: Boolean;
    procedure DisconnectServer;

    function ConnectWebsocketServer: Boolean;
    procedure DisconnectWebsocketServer;

    function ConnectHTTPServer: Boolean;
    procedure DisconnectHTTPServer;

    function ConnectComPortServer: Boolean;
    procedure DisconnectComPortServer;

    // Callbacks from the Ethernet Server
    procedure OnCommandStationServerConnectionState(Sender: TObject; Info: TLccHardwareConnectionInfo);
    procedure OnCommandStationServerErrorMessage(Sender: TObject; Info: TLccHardwareConnectionInfo);
    // Callbacks from the Websocket Server
    procedure OnCommandStationWebsocketConnectionState(Sender: TObject; Info: TLccHardwareConnectionInfo);
    procedure OnCommandStationWebsocketErrorMessage(Sender: TObject; Info: TLccHardwareConnectionInfo);
    // Callbacks from the HTTP Server
    procedure OnCommandStationHTTPConnectionState(Sender: TObject; Info: TLccHardwareConnectionInfo);
    procedure OnCommandStationHTTPErrorMessage(Sender: TObject; Info: TLccHardwareConnectionInfo);

    // Callbacks from the ComPort
    procedure OnComPortConnectionStateChange(Sender: TObject; Info: TLccHardwareConnectionInfo);
    procedure OnComPortErrorMessage(Sender: TObject; Info: TLccHardwareConnectionInfo);
    procedure OnComPortReceiveMessage(Sender: TObject; Info: TLccHardwareConnectionInfo);
    procedure OnComPortSendMessage(Sender: TObject; var GridConnectStyleMessage: string);

    // Callbacks from the Node Manager
    procedure OnNodeManagerSendMessage(Sender: TObject; LccMessage: TLccMessage);
    procedure OnNodeManagerReceiveMessage(Sender: TObject; LccMessage: TLccMessage);
    procedure OnNodeManagerAliasIDChanged(Sender: TObject; LccSourceNode: TLccNode);
    procedure OnNodeManagerIDChanged(Sender: TObject; LccSourceNode: TLccNode);
    procedure OnNodeManagerNodeLogout(Sender: TObject; LccSourceNode: TLccNode);
    procedure OnNodeManagerNodeLogin(Sender: TObject; LccSourceNode: TLccNode);


    procedure OnNodeTractionListenerAttach(Sender: TObject; LccNode: TLccNode; AMessage: TLccMessage; var DoDefault: Boolean);
    procedure OnNodeTractionListenerDetach(Sender: TObject; LccNode: TLccNode; AMessage: TLccMessage; var DoDefault: Boolean);
    procedure OnNodeTractionListenerQuery(Sender: TObject; LccNode: TLccNode; AMessage: TLccMessage; var DoDefault: Boolean);

    // Other
    procedure OnAliasMappingChange(Sender: TObject; LccSourceNode: TLccNode; AnAliasMapping: TLccAliasMapping; IsMapped: Boolean);
    procedure OnTractionRegisterNotify(TractionObject: TLccTractionObject; IsRegistered: Boolean);
    procedure OnTractionNotify(TractionObject: TLccTractionObject);

    function TrainNodeToCaption(ATrainNode: TLccTrainDccNode): string;
    function FindSingleLevelNodeWithData(ParentNode: TTreeNode; const NodeData: Pointer): TTreeNode;
    procedure RebuildTrainListview;
    procedure ReleaseAliasOnTrains;

  public
    property LccServer: TLccEthernetServer read FLccServer write FLccServer;
  //  property LccWebsocketServer: TLccWebsocketServer read FLccWebsocketServer write FLccWebsocketServer;
  //  property LccHTTPServer: TLccHTTPServer read FLccHTTPServer write FLccHTTPServer;
    property NodeManager: TLccNodeManager read FNodeManager write FNodeManager;
    property ComPort: TLccComPort read FComPort write FComPort;

    property CommandStationNode: TLccCommandStationNode read FCommandStationNode write FCommandStationNode;
  end;

var
  FormTrainCommander: TFormTrainCommander;

implementation

{$R *.lfm}

{ TFormTrainCommander }

procedure TFormTrainCommander.ButtonHTTPServerClick(Sender: TObject);
begin
 // if LccHTTPServer.ListenerConnected then
 //   DisconnectHTTPServer
 // else
 //   ConnectHTTPServer;
end;

procedure TFormTrainCommander.ButtonWebserverConnectClick(Sender: TObject);
begin
 // if LccWebsocketServer.ListenerConnected then
 //   DisconnectWebsocketServer
 // else
 //   ConnectWebsocketServer;
end;

procedure TFormTrainCommander.ButtonManualConnectComPortClick(Sender: TObject);
begin
  if ComPort.Connected then
    DisconnectComPortServer
  else
    ConnectComPortServer;
end;

procedure TFormTrainCommander.ButtonClearClick(Sender: TObject);
begin
  MemoLog.Lines.BeginUpdate;
  try
    MemoLog.Lines.Clear;
  finally
    MemoLog.Lines.EndUpdate;
  end;

  MemoComPort.Lines.BeginUpdate;
  try
    MemoComPort.Lines.Clear;
  finally
    MemoComPort.Lines.EndUpdate;
  end;
end;

procedure TFormTrainCommander.ButtonEthernetConnectClick(Sender: TObject);
begin
  if LccServer.Connected then
    DisconnectServer
  else
    ConnectServer;
end;

procedure TFormTrainCommander.ButtonTrainsReleaseAliasClick(Sender: TObject);
begin
  ReleaseAliasOnTrains
end;

procedure TFormTrainCommander.CheckBox1Change(Sender: TObject);
begin
  if CheckBox1.Checked then
  begin
    Max_Allowed_Buffers := 1;
  end else
  begin
    Max_Allowed_Buffers := 2048;
  end;
end;

function TFormTrainCommander.ConnectServer: Boolean;
var
  LocalInfo: TLccEthernetConnectionInfo;
begin
  Result := False;
  LocalInfo := TLccEthernetConnectionInfo.Create;
  try
    LocalInfo.AutoResolveIP := not CheckBoxLoopBackIP.Checked;
    LocalInfo.ListenerIP := '127.0.0.1';
    LocalInfo.ListenerPort := 12021;
    LocalInfo.GridConnect := True;
    LocalInfo.Hub := True;
    Result := LccServer.OpenConnection(LocalInfo) <> nil;
  finally
  end;
end;

procedure TFormTrainCommander.DisconnectServer;
begin
  LccServer.CloseConnection;
end;

function TFormTrainCommander.ConnectWebsocketServer: Boolean;
var
  LocalInfo: TLccEthernetConnectionInfo;
begin
  Result := False;
  LocalInfo := TLccEthernetConnectionInfo.Create;
  try
    LocalInfo.AutoResolveIP := not CheckBoxLoopBackIP.Checked;
    LocalInfo.ListenerIP := '127.0.0.1';
    LocalInfo.ListenerPort := 12022;
    LocalInfo.GridConnect := True;
    LocalInfo.Hub := True;
  finally
    LocalInfo.Free;
  end;
end;

procedure TFormTrainCommander.DisconnectWebsocketServer;
begin
 // LccWebsocketServer.CloseConnection(nil);
end;

function TFormTrainCommander.ConnectHTTPServer: Boolean;
var
    LocalInfo: TLccEthernetConnectionInfo;
begin
  Result := False;
  LocalInfo := TLccEthernetConnectionInfo.Create;
  try
    LocalInfo.AutoResolveIP := not CheckBoxLoopBackIP.Checked;
    LocalInfo.ListenerIP := '127.0.0.1';
    LocalInfo.ListenerPort := 12020;
  //  Result := LccHTTPServer.OpenConnection(LocalInfo) <> nil;
  finally
    LocalInfo.Free;
  end;
end;

procedure TFormTrainCommander.DisconnectHTTPServer;
begin
 // LccHTTPServer.CloseConnection(nil);
end;

function TFormTrainCommander.ConnectComPortServer: Boolean;
var
  LocalInfo: TLccComPortConnectionInfo;
begin
  Result := False;
  LocalInfo := TLccComPortConnectionInfo.Create;
  try
    LocalInfo.ComPort := ComboBoxComPorts.Items[ComboBoxComPorts.ItemIndex];
    LocalInfo.Baud := 9600;
    LocalInfo.StopBits := 8;
    LocalInfo.Parity := 'N';
    LocalInfo.GridConnect := True;
    Result := Assigned(ComPort.OpenConnection(LocalInfo))
  finally
    LocalInfo.Free;
  end;
end;

procedure TFormTrainCommander.DisconnectComPortServer;
begin
  ComPort.CloseConnection;
end;

procedure TFormTrainCommander.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
  CanClose := CanClose; // Keep Hints quiet
  ComPort.CloseConnection;
  LccServer.CloseConnection;
 // LccWebsocketServer.CloseConnection;
//  LccHTTPServer.CloseConnection;
end;

procedure TFormTrainCommander.FormCreate(Sender: TObject);
begin
  NodeManager := TLccNodeManager.Create(nil, True);
  NodeManager.OnNodeAliasIDChanged := @OnNodeManagerAliasIDChanged;
  NodeManager.OnNodeIDChanged := @OnNodeManagerIDChanged;
  NodeManager.OnNodeLogin := @OnNodeManagerNodeLogin;
  NodeManager.OnNodeTractionListenerAttach := @OnNodeTractionListenerAttach;
  NodeManager.OnNodeTractionListenerDetach := @OnNodeTractionListenerDetach;
  NodeManager.OnNodeTractionListenerQuery := @OnNodeTractionListenerQuery;
  NodeManager.OnAliasMappingChange := @OnAliasMappingChange;

  FLccServer := TLccEthernetServer.Create(nil, NodeManager);
  LccServer.OnConnectionStateChange := @OnCommandStationServerConnectionState;
  LccServer.OnErrorMessage := @OnCommandStationServerErrorMessage;
  LccServer.OnLccMessageReceive := @OnNodeManagerReceiveMessage;
  LccServer.OnLccMessageSend := @OnNodeManagerSendMessage;
  LccServer.Hub := True;

//  FLccWebsocketServer := TLccWebsocketServer.Create(nil, NodeManager);
 // LccWebsocketServer.OnConnectionStateChange := @OnCommandStationWebsocketConnectionState;
 // LccWebsocketServer.OnErrorMessage := @OnCommandStationWebsocketErrorMessage;


//  FLccHTTPServer := TLccHTTPServer.Create(nil, NodeManager); // OpenLCB messages do not move on this interface
//  LccHTTPServer.OnConnectionStateChange := @OnCommandStationHTTPConnectionState;
//  LccHTTPServer.OnErrorMessage := @OnCommandStationHTTPErrorMessage;

  ComPort := TLccComPort.Create(nil, NodeManager); // This is only to send Raw GridConnect Message to the CS so it is defined as not a LCCLink
  ComPort.OnConnectionStateChange := @OnComPortConnectionStateChange;
  ComPort.OnErrorMessage := @OnComPortErrorMessage;
  ComPort.OnReceiveMessage := @OnComPortReceiveMessage;
  ComPort.RawData := True;

  Max_Allowed_Buffers := 1;

  FWorkerMessage := TLccMessage.Create;
end;

procedure TFormTrainCommander.FormDestroy(Sender: TObject);
begin
  NodeManager.ReleaseAliasAll;
 // FreeAndNil(FLccHTTPServer);
  FreeAndNil(FLccServer);
 // FreeAndNil(FLccWebsocketServer);
  FreeAndNil(FComPort);
  FreeAndNil(FNodeManager);   // after the servers are destroyed
  FreeAndNil(FWorkerMessage);
end;

procedure TFormTrainCommander.FormShow(Sender: TObject);
begin
  ComboBoxComPorts.Items.Delimiter := ';';
  ComboBoxComPorts.Items.DelimitedText := StringReplace(GetSerialPortNames, ',', ';', [rfReplaceAll, rfIgnoreCase]);
  ComboBoxComPorts.ItemIndex := 0;
end;

procedure TFormTrainCommander.OnCommandStationServerConnectionState(Sender: TObject; Info: TLccHardwareConnectionInfo);
var
  ListItem: TListItem;
begin

  case Info.ConnectionState of
    lcsConnecting :
      begin
        ButtonEthernetConnect.Enabled := False;
        StatusBarMain.Panels[0].Text := 'Connecting to Ethernet';
      end;
    lcsConnected :
      begin
        ButtonEthernetConnect.Enabled := True;
        ButtonEthernetConnect.Caption := 'Disconnect Ethernet';
        StatusBarMain.Panels[0].Text := 'Ethernet: Command Station Connected at: ' + (Info as TLccEthernetConnectionInfo).ListenerIP + ':' + IntToStr((Info as TLccEthernetConnectionInfo).ListenerPort);
        if NodeManager.Nodes.Count = 0 then
          CommandStationNode := NodeManager.AddNodeByClass('', TLccCommandStationNode , True, NULL_NODE_ID) as TLccCommandStationNode;
        if Assigned(CommandStationNode) then
        begin
          CommandStationNode.TractionServer.OnSpeedChange := @OnTractionNotify;
          CommandStationNode.TractionServer.OnEmergencyStopChange := @OnTractionNotify;
          CommandStationNode.TractionServer.OnFunctionChange := @OnTractionNotify;
          CommandStationNode.TractionServer.OnSNIPChange := @OnTractionNotify;
          CommandStationNode.TractionServer.OnTrainSNIPChange := @OnTractionNotify;
          CommandStationNode.TractionServer.OnRegisterChange := @OnTractionRegisterNotify;
        end;
      end;
    lcsDisconnecting :
      begin
        ButtonEthernetConnect.Enabled := False;
        ButtonEthernetConnect.Caption := 'Command Station Disconnecting from Ethernet';
        // We are not clearing the nodes, only disconnecting the connection.  There is no such thing
        // as taking a node offline in OpenLCB, only reallocating an Alias if a duplicate is found (handled
        // automatically in the library) or totally off line if the NodeID is found to be a duplicate
      end;
    lcsDisconnected :
      begin
        ButtonEthernetConnect.Enabled := True;
        ButtonEthernetConnect.Caption := 'Connect Ethernet';
        StatusBarMain.Panels[0].Text := 'Command Station Disconnected from Ethernet';
      end;
    lcsClientConnected :
      begin
        ListItem := ListviewConnections.Items.Add;
        Listitem.Caption := 'Throttle connected via Ethernet: ' + (Info as TLccEthernetConnectionInfo).ClientIP + ':' + IntToStr((Info as TLccEthernetConnectionInfo).ClientPort);
        ListItem.ImageIndex := 3;
      end;
    lcsClientDisconnected :
      begin
        ListItem := ListviewConnections.FindCaption(0, 'Throttle connected via Ethernet: ' + (Info as TLccEthernetConnectionInfo).ClientIP + ':' + IntToStr((Info as TLccEthernetConnectionInfo).ClientPort), True, True, True, True);
        if Assigned(ListItem) then
          ListviewConnections.Items.Delete(ListItem.Index);
      end;
  end;
end;

procedure TFormTrainCommander.OnCommandStationServerErrorMessage(Sender: TObject; Info: TLccHardwareConnectionInfo);
begin
  ShowMessage('TCP Server: ' + Info.MessageStr);

end;

procedure TFormTrainCommander.OnCommandStationWebsocketConnectionState(Sender: TObject; Info: TLccHardwareConnectionInfo);
var
  ListItem: TListItem;
begin
  if Sender is TLccEthernetListener then
  begin
    case Info.ConnectionState of
      lcsConnecting :
        begin
          ButtonWebserverConnect.Enabled := False;
          StatusBarMain.Panels[1].Text := 'Connecting to Websocket';
        end;
      lcsConnected :
        begin
          ButtonWebserverConnect.Enabled := True;
          ButtonWebserverConnect.Caption := 'Disconnect Websocket';
          StatusBarMain.Panels[1].Text := 'Websocket: Command Station Connected at: ' + (Info as TLccEthernetConnectionInfo).ListenerIP + ':' + IntToStr((Info as TLccEthernetConnectionInfo).ListenerPort);
          if NodeManager.Nodes.Count = 0 then
            NodeManager.AddNodeByClass('', TLccCommandStationNode, True, NULL_NODE_ID);
          end;
      lcsDisconnecting :
        begin
          ButtonWebserverConnect.Enabled := False;
          ButtonWebserverConnect.Caption := 'Connect Websocket';
          StatusBarMain.Panels[1].Text := 'Command Station Disconnected from Websocket';
          if not LccServer.Connected then
            NodeManager.Clear;
        end;
      lcsDisconnected :
        begin
          ButtonWebserverConnect.Enabled := True;
          ButtonWebserverConnect.Caption := 'Connect Ethernet';
          StatusBarMain.Panels[1].Text := 'Command Station Disconnected from Websocket';
        end;
    end;

  end else
  if Sender is TLccConnectionThread then
  begin
    case Info.ConnectionState of
      lcsConnecting :
        begin
        end;
      lcsConnected :
        begin
          ListItem := ListviewConnections.Items.Add;
          Listitem.Caption := 'Throttle connected via Websocket: ' + (Info as TLccEthernetConnectionInfo).ClientIP + ':' + IntToStr((Info as TLccEthernetConnectionInfo).ClientPort);
          ListItem.ImageIndex := 3;
        end;
      lcsDisconnecting :
        begin
        end;
      lcsDisconnected :
        begin
          ListItem := ListviewConnections.FindCaption(1, 'Throttle connected via Websocket: ' + (Info as TLccEthernetConnectionInfo).ClientIP + ':' + IntToStr((Info as TLccEthernetConnectionInfo).ClientPort), True, True, True, True);
          if Assigned(ListItem) then
            ListviewConnections.Items.Delete(ListItem.Index);
        end;
    end;
  end;
end;

procedure TFormTrainCommander.OnCommandStationWebsocketErrorMessage(
  Sender: TObject; Info: TLccHardwareConnectionInfo);
begin
 //  ShowMessage('Websocket Server: ' + EthernetRec.MessageStr);
  Info := Info;
end;

procedure TFormTrainCommander.OnCommandStationHTTPConnectionState(Sender: TObject; Info: TLccHardwareConnectionInfo);
var
  ListItem: TListItem;
begin
  if Sender is TLccEthernetListener then
  begin
    case Info.ConnectionState of
      lcsConnecting :
        begin
          StatusBarMain.Panels[2].Text := 'HTTP Server Connecting';
          ButtonHTTPServer.Enabled := False;
        end;
      lcsConnected :
        begin
          StatusBarMain.Panels[2].Text := 'HTTP Server Connected: ' + (Info as TLccEthernetConnectionInfo).ListenerIP + ':' + IntToStr((Info as TLccEthernetConnectionInfo).ListenerPort);
          ButtonHTTPServer.Caption := 'HTTP Disconnect';
          ButtonHTTPServer.Enabled := True;
        end;
      lcsDisconnecting :
        begin
          ButtonHTTPServer.Caption := 'Disconnecting from HTTP Server';
          ButtonHTTPServer.Enabled := False;
        end;
      lcsDisconnected :
        begin
          StatusBarMain.Panels[2].Text := 'HTTP Server Disconnected';
          ButtonHTTPServer.Caption := 'HTTP Connect';
          ButtonHTTPServer.Enabled := True;
        end;
    end;

  end else
  if Sender is TLccConnectionThread then
  begin
    case Info.ConnectionState of
      lcsConnecting :
        begin
        end;
      lcsConnected :
        begin
          ListItem := ListviewConnections.Items.Add;
          Listitem.Caption := 'Device connected HTTP: ' + (Info as TLccEthernetConnectionInfo).ClientIP + ':' + IntToStr((Info as TLccEthernetConnectionInfo).ClientPort);
          ListItem.ImageIndex := 3;
        end;
      lcsDisconnecting :
        begin
        end;
      lcsDisconnected :
        begin
          ListItem := ListviewConnections.FindCaption(1, 'Device connected HTTP: ' + (Info as TLccEthernetConnectionInfo).ClientIP + ':' + IntToStr((Info as TLccEthernetConnectionInfo).ClientPort), True, True, True, True);
          if Assigned(ListItem) then
            ListviewConnections.Items.Delete(ListItem.Index);
        end;
    end;
  end
end;

procedure TFormTrainCommander.OnCommandStationHTTPErrorMessage(Sender: TObject; Info: TLccHardwareConnectionInfo);
begin
  ShowMessage('HTTP Server: ' + Info.MessageStr);
end;

procedure TFormTrainCommander.OnNodeManagerAliasIDChanged(Sender: TObject; LccSourceNode: TLccNode);
begin
  if LccSourceNode is TLccCommandStationNode then
    LabelAliasID.Caption := LccSourceNode.AliasIDStr;
end;

procedure TFormTrainCommander.OnNodeManagerIDChanged(Sender: TObject; LccSourceNode: TLccNode);
begin
  if LccSourceNode is TLccCommandStationNode then
    LabelNodeID.Caption := LccSourceNode.NodeIDStr;
end;

procedure TFormTrainCommander.OnNodeManagerNodeLogin(Sender: TObject; LccSourceNode: TLccNode);
var
  TrainNode: TLccTrainDccNode;
  TreeNode: TTreeNode;
begin
  if LccSourceNode is TLccTrainDccNode then
  begin
    TrainNode := LccSourceNode as TLccTrainDccNode;

    TrainNode.OnSendMessageComPort := @OnComPortSendMessage;

    TreeNode := TreeViewTrains.Items.Add(nil, TrainNodeToCaption(TrainNode));
    TreeNode.Data := TrainNode;
    TreeNode.ImageIndex := 18;
  end;
end;

procedure TFormTrainCommander.OnNodeTractionListenerAttach(Sender: TObject;
  LccNode: TLccNode; AMessage: TLccMessage; var DoDefault: Boolean);
begin
  RebuildTrainListview;
end;

procedure TFormTrainCommander.OnNodeTractionListenerDetach(Sender: TObject;
  LccNode: TLccNode; AMessage: TLccMessage; var DoDefault: Boolean);
begin
  RebuildTrainListview ;
end;

procedure TFormTrainCommander.OnNodeTractionListenerQuery(Sender: TObject;
  LccNode: TLccNode; AMessage: TLccMessage; var DoDefault: Boolean);
begin

end;

procedure TFormTrainCommander.OnAliasMappingChange(Sender: TObject; LccSourceNode: TLccNode; AnAliasMapping: TLccAliasMapping; IsMapped: Boolean);
begin
  if IsMapped then
    FormServerInfo.AddAliasMap(AnAliasMapping)
  else
    FormServerInfo.RemoveAliasMap(AnAliasMapping);
end;

procedure TFormTrainCommander.OnTractionRegisterNotify(
  TractionObject: TLccTractionObject; IsRegistered: Boolean);
begin
  if IsRegistered then
    FormServerInfo.AddTrainObject(TractionObject)
  else
    FormServerInfo.RemoveTrainObject(TractionObject);
end;

procedure TFormTrainCommander.OnTractionNotify(
  TractionObject: TLccTractionObject);
begin

end;

function TFormTrainCommander.TrainNodeToCaption(ATrainNode: TLccTrainDccNode): string;
var
  SpeedStep: string;
begin
  case ATrainNode.DccSpeedStep of
    ldssDefault : SpeedStep := 'Default Step';
    ldss14      : SpeedStep := '14 Step';
    ldss28      : SpeedStep := '28 Step';
    ldss128     : SpeedStep := '128 Step';
  end;

  if ATrainNode.DccLongAddress then
    Result := IntToStr(ATrainNode.DccAddress) + ' Long ' + SpeedStep + ' [' + ATrainNode.AliasIDStr + ']' + ' [' + ATrainNode.NodeIDStr + ']'
  else
    Result := IntToStr(ATrainNode.DccAddress) + ' Short ' + SpeedStep + ' [' + ATrainNode.AliasIDStr + ']' + ' [' + ATrainNode.NodeIDStr + ']';
end;

function TFormTrainCommander.FindSingleLevelNodeWithData(ParentNode: TTreeNode;
  const NodeData: Pointer): TTreeNode;
begin
  if ParentNode = nil then
    Result := TreeViewTrains.Items.GetFirstNode
  else
    Result := ParentNode.GetFirstChild;
  while Assigned(Result) and (Result.Data <> NodeData) do
    Result := Result.GetNextSibling;
end;

procedure TFormTrainCommander.RebuildTrainListview;
var
  ListenerTrainNode, ParentTrainNode: TLccTrainDccNode;
  ParentTreeNode, ChildTreeNode: TTreeNode;
  i, j: Integer;
begin
  TreeViewTrains.Items.Clear;

  for i := 0 to NodeManager.Nodes.Count - 1 do
  begin
    if TLccNode( NodeManager.Nodes[i]) is TLccTrainDccNode then
    begin
      ParentTrainNode := TLccNode( NodeManager.Nodes[i]) as TLccTrainDccNode;
      ParentTreeNode := TreeViewTrains.Items.Add(nil, TrainNodeToCaption(ParentTrainNode));
      ParentTreeNode.ImageIndex := 18;
      for j := 0 to ParentTrainNode.Listeners.Count - 1 do
      begin
        ListenerTrainNode := NodeManager.FindNode(ParentTrainNode.Listeners.Listener[j].NodeID) as TLccTrainDccNode;
        if Assigned(ListenerTrainNode) then
        begin
           ChildTreeNode := TreeViewTrains.Items.AddChild(ParentTreeNode, TrainNodeToCaption(ListenerTrainNode));
           ChildTreeNode.ImageIndex := 7;
        end else
        begin
           ChildTreeNode := TreeViewTrains.Items.AddChild(ParentTreeNode, '[Unknown]');
           ChildTreeNode.ImageIndex := 7;
        end;
      end;
    end;
  end;
end;

procedure TFormTrainCommander.ReleaseAliasOnTrains;
var
  i: Integer;
  TrainNode: TLccTrainDccNode;
begin
  for i := NodeManager.Nodes.Count - 1 downto 0  do
  begin
    if TLccNode(NodeManager.Nodes.Items[i]) is TLccTrainDccNode then
    begin
      TrainNode := TLccNode(NodeManager.Nodes.Items[i]) as TLccTrainDccNode;
      TrainNode.ReleaseAlias(100);
    end;
  end;
end;

procedure TFormTrainCommander.OnComPortConnectionStateChange(Sender: TObject; Info: TLccHardwareConnectionInfo);
begin
  if Sender is TLccConnectionThread then
  begin
    case (Info as TLccComPortConnectionInfo).ConnectionState of
      lcsConnecting :    StatusBarMain.Panels[3].Text := 'ComPort Connecting';
      lcsConnected :
        begin
          StatusBarMain.Panels[3].Text := 'ComPort: ' + (Info as TLccComPortConnectionInfo).ComPort;
          ButtonManualConnectComPort.Caption := 'Close ComPort';
        end;
      lcsDisConnecting : StatusBarMain.Panels[3].Text := 'ComPort Disconnectiong';
      lcsDisconnected :
        begin
          ButtonManualConnectComPort.Caption := 'Open ComPort';
          StatusBarMain.Panels[3].Text := 'ComPort Disconnected';
        end;
    end;
  end;
end;

procedure TFormTrainCommander.OnComPortErrorMessage(Sender: TObject;
  Info: TLccHardwareConnectionInfo);
begin
  ShowMessage(Info.MessageStr);
end;

procedure TFormTrainCommander.OnComPortReceiveMessage(Sender: TObject; Info: TLccHardwareConnectionInfo);
begin
  MemoComPort.Lines.BeginUpdate;
  try
    MemoComPort.Lines.Add('R: ' + Info.MessageStr);
    MemoComPort.SelStart := Length(MemoComPort.Lines.Text);
  finally
    MemoComPort.Lines.EndUpdate;
  end;
end;

procedure TFormTrainCommander.OnComPortSendMessage(Sender: TObject; var GridConnectStyleMessage: string);
begin
  ComPort.SendMessageRawGridConnect(GridConnectStyleMessage);

  MemoComPort.Lines.BeginUpdate;
  try
    MemoComPort.Lines.Add('S: ' + GridConnectStyleMessage);
    MemoComPort.SelStart := Length(MemoComPort.Lines.Text);
  finally
    MemoComPort.Lines.EndUpdate;
  end;
end;

procedure TFormTrainCommander.OnNodeManagerNodeLogout(Sender: TObject; LccSourceNode: TLccNode);
{var
  TreeNode: TTreeNode;
  TrainNode: TLccTrainDccNode;      }
begin
{  if LccSourceNode is TLccTrainDccNode then
  begin
    TrainNode := LccSourceNode as TLccTrainDccNode;
    TreeNode := TreeViewTrains.Items.FindNodeWithData(TrainNode);
    while Assigned(TreeNode) do
    begin
      if Assigned(TreeNode) then
        TreeViewTrains.Items.Delete(TreeNode);
      TreeNode := TreeViewTrains.Items.FindNodeWithData(LccSourceNode);
    end;
  end;     }
end;

procedure TFormTrainCommander.OnNodeManagerReceiveMessage(Sender: TObject; LccMessage: TLccMessage);
begin
  if CheckBoxLogMessages.Checked then
  begin
    MemoLog.Lines.BeginUpdate;
    try
      if CheckBoxDetailedLog.Checked then
        MemoLog.Lines.Add('R: ' + MessageToDetailedMessage(LccMessage))
      else
        MemoLog.Lines.Add('R: ' + LccMessage.ConvertToGridConnectStr('', False));
      MemoLog.SelStart := Length(MemoLog.Lines.Text);
    finally
      MemoLog.Lines.EndUpdate;
    end;
  end;
end;

procedure TFormTrainCommander.OnNodeManagerSendMessage(Sender: TObject; LccMessage: TLccMessage);
begin
  if CheckBoxLogMessages.Checked then
  begin
    MemoLog.Lines.BeginUpdate;
    try
      if CheckBoxDetailedLog.Checked then
        MemoLog.Lines.Add('S: ' + MessageToDetailedMessage(LccMessage))
      else
        MemoLog.Lines.Add('S: ' + LccMessage.ConvertToGridConnectStr('', False));
      MemoLog.SelStart := Length(MemoLog.Lines.Text);
    finally
      MemoLog.Lines.EndUpdate;
    end;
  end;
end;

procedure TFormTrainCommander.ToggleBoxServerFormChange(Sender: TObject);
begin
  if ToggleBoxServerForm.Checked then
    FormServerInfo.Show
  else
    FormServerInfo.Hide
end;

end.


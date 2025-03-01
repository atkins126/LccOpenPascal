program TrainCommander;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, memdslaz, TrainCommanderUnit, TrainDatabaseUnit, lcc_ethernet_common,
  lcc_ethernet_http, servervisualunit, 
lcc_node_traindatabase, lcc_listener_tree, lcc_base_classes;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Scaled:=True;
  Application.Initialize;
  Application.CreateForm(TFormTrainCommander, FormTrainCommander);
  Application.CreateForm(TFormServerInfo, FormServerInfo);
  Application.Run;
end.


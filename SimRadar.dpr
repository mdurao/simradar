program SimRadar;

uses
  Forms,
  fMain in 'fMain.pas' {Form1};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'SimRadar';
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.

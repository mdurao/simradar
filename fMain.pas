unit fMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms, Dialogs, ExtCtrls, StdCtrls, ComCtrls, Math,
  Menus;

type
  TmyPoint = Record
    lat: double;
    lon: double;
    X: double;
    Y: double;
    Xi: Integer;
    Yi: Integer;
  end;

type
  TSegmentoMapa = Record
    Ponto1 : TmyPoint;
    Ponto2 : TmyPoint;
    Color : TColor;
  End;

Type
  TVectorElastico = Record
    PontoInicial : TmyPoint;
    PontoFinal : TmyPoint;
    isSelected : Bool;
    Distance : Integer;
    Heading : Integer;
    CoHeading : Integer;
  End;

type
  TFixes = Record
    Ponto : TmyPoint;
    Nome : String;
  End;

type
  TForm1 = class(TForm)
    PaintBox1: TPaintBox;
    Timer1: TTimer;
    StatusBar1: TStatusBar;
    MainMenu1: TMainMenu;
    Hello1: TMenuItem;
    Reset1: TMenuItem;
    ResetVectors1: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure DesenharMapa(Sender: TObject);
    procedure PaintBox1MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure PaintBox1MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure PaintBox1MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure FormMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure FormShow(Sender: TObject);
    procedure CalculaPontos();
    function detectLabel(x,y : Integer) : Integer;
    procedure DeleteElement(const aPosition:integer);
    procedure Reset1Click(Sender: TObject);
    procedure ResetVectors1Click(Sender: TObject);
  private
    { Private declarations }
    Mapa: Array of TsegmentoMapa;
    Fixes: Array of Tfixes;
    Vors: Array of Tfixes;
    NDBs: Array of Tfixes;
    VectoresElasticos: Array of TVectorElastico;
    procedure ReadSectorFile(filename : string);
    procedure ReadFixesFile(filename: String);
    procedure ReadVorsFile(filename: String);
    procedure ReadNDBsFile(filename: String);
  public
    { Public declarations }
  end;

var
  Form1: TForm1;
  xLow, xHigh, yLow, yHigh: double;
  tlx, brx, tly, bry: Integer;
  zoom: double;
  startx, starty, lastx, lasty, deltax, deltay: double;
  state: Integer;
  startxi, startyi, lastxi, lastyi, deltaxi, deltayi: Integer;
  xDelta, yDelta : Double;
  startlat, startlon, lastlat, lastlon : Double;
  showFixes, showVORs, showNDBs : Boolean;
  XwMin, XwMax, YwMin, YwMax : Double;
  XvMin, XvMax, YvMin, YvMax : Integer;
  Sx, Cx, Sy, Cy : Double;
  delLabel : Integer;

const
  R = 6371000; // meters
  c_coast = TColor($008080);
  c_maroon = TColor($000080);
  c_TWR = TColor($FF0000);
  c_RVA = TColor($470048);
  c_TMA = TColor($0000AE);
  labelWidth = 58;
  labelHeight = 30;
  radarWidth = 1800;
  radarHeight = 1000;

implementation

{$R *.dfm}

procedure CenterForm(f:TForm);
begin
  f.Top:=(Screen.WorkAreaHeight-f.Height) div 2;
  if f.Top<0 then f.Top:=0;
  f.Left:=(Screen.WorkAreaWidth-f.Width) div 2;
  if f.Left<0 then f.Left:=0;
end;

function mapW2SxLin(xf: double): Integer;
begin
  result := round(tlx + (xf - xLow) * (brx - tlx) / (xHigh - xLow));
end;

function mapW2SyLin(yf: double): Integer;
begin
  result := round(bry - (yf - yLow) * (bry - tly) / (yHigh - yLow));
end;

function mapS2WxLin(xs: Integer): double;
begin
  result := xLow + (xs - tlx) * (xHigh - xLow) / (brx - tlx);
end;

function mapS2WyLin(ys: Integer): double;
begin
  result := yHigh - (ys - tly) * (yHigh - yLow) / (bry - tly);
end;

Function StringToDouble(Ponto: String): Double;
  var
    tSec : String;
    MyResult: Double;
    Direccao: Char;
    Grau: Double;
    Minuto: Double;
    Segundo: Double;
  begin
    Direccao := Ponto[1];
    Grau := StrToFloat(Copy(Ponto,2,3));
    Minuto := StrToFloat(Copy(Ponto,6,2));
    tSec := Copy(Ponto,9,6);
    if tSec[3] = ',' then tSec[3] := '.';
    Segundo := StrToFloat(tSec);
    MyResult := Grau + (Minuto/60) + (Segundo/3600);
    if (Direccao = 'S') or (Direccao = 'W') then MyResult := -1 * MyResult;
    result := MyResult;
  end;

Function CoordToCart(Ponto: TmyPoint) : TmyPoint;
  var
    x, y : Double;
  begin
    x := R * DegToRad(Ponto.lon) / 1852;
    y := (R * (ln(tan(Pi/4+DegToRad(Ponto.lat)/2))))/1852;
    Ponto.X := x;
    Ponto.Y := y;
    result := Ponto;
  end;

Function CartToCoord(Ponto: TmyPoint) : TmyPoint;
  var
    lat,lon : Double;
  begin
    lon := RadToDeg(Ponto.X / R * 1852);
    lat := RadToDeg(Pi/2 - 2 * arctan(exp(-Ponto.Y/R * 1852)));
    Ponto.lat := lat;
    Ponto.lon := lon;
    result := Ponto;
  end;

Function HumanCoord(Ponto: TmyPoint; dir : bool) : String;
var
  lat : Double;
  Graus, Minutos, Segundos : integer;
  dirStr, grausStr, minutosStr, segundoStr : String;
begin
  if dir = false then
    begin
      lat := Ponto.lat;
      if (lat) > 0 then dirStr := 'N'
      else dirStr := 'S';
    end
  else
    begin
      lat := Ponto.lon;
      if (lat) > 0 then dirStr := 'E'
      else dirStr := 'W';
    end;
  if lat < 0 then lat := lat * -1;
  graus := trunc(lat);
  if Graus < 100 then grausStr := '0'+IntToStr(Graus);
  if Graus < 10 then grausStr := '00'+IntToStr(Graus);
  lat := (graus - lat) * -60;
  Minutos := trunc(lat);
  if Minutos < 100 then minutosStr := '0'+IntToStr(Minutos);
  if Minutos < 10 then minutosStr := '00'+IntToStr(Minutos);
  Segundos := Trunc((Minutos - lat) * -60);
  if Segundos < 100 then segundoStr := '0'+IntToStr(Segundos);
  if Segundos < 10 then segundoStr := '00'+IntToStr(Segundos);
  result := dirStr+' '+grausStr+'º'+minutosStr+'´'+segundoStr+'´´';
end;

Function atan2(y : extended; x : extended): Extended;
Assembler;
  asm
    fld [y]
    fld [x]
    fpatan
  end;

function calculateDistance(ponto1, ponto2 : tmypoint) : integer;
var
  dlat, dlon, a, c, latr1, latr2, lonr1, lonr2, d : double;
begin
  latr1 := DegToRad(ponto1.lat);
  lonr1 := DegToRad(ponto1.lon);
  latr2 := DegToRad(ponto2.lat);
  lonr2 := DegToRad(ponto2.lon);
  dlat := latr2 - latr1;
  dlon := lonr2 - lonr1;
  a := Sin(dlat/2) * Sin(dlat/2) + Sin(dlon/2) * Sin(dlon/2) * Cos(latr1) * Cos(latr2);
  c := 2 * atan2(sqrt(a), sqrt(1-a));
  d := R * c / 1852;
  result := Round(d);
end;

function calculateBearing(ponto1, ponto2 : tmypoint) : double;
var
  dlon, latr1, latr2, lonr1, lonr2, b : double;
  x, y : double;
begin
  latr1 := DegToRad(ponto1.lat);
  lonr1 := DegToRad(ponto1.lon);
  latr2 := DegToRad(ponto2.lat);
  lonr2 := DegToRad(ponto2.lon);
  dlon := lonr2 - lonr1;
  y := Sin(dlon)*Cos(latr2);
  x := Cos(latr1)*Sin(latr2) - Sin(latr1)*Cos(latr2)*Cos(dlon);
  b := atan2(y,x);
  b := RadToDeg(b);
  result := b;
end;

function TForm1.detectLabel(x,y : Integer) : Integer;
var
  len, i : Integer;
  tx, ty, txlim, tylim : Integer;
  res : Integer;
begin
  len := Length(VectoresElasticos);
  res := -1;
  for i := 0 to len - 1 do
    begin
      tx := VectoresElasticos[i].PontoFinal.Xi;
      ty := VectoresElasticos[i].PontoFinal.Yi;
      txlim := tx+labelWidth;
      tylim := ty+labelHeight;
      if (x >= tx) and (x <= txlim) and (y >= ty) and (y <= tylim) then
        begin
          res := i;
        end;
    end;
  result := res;
end;

procedure TForm1.DeleteElement(const aPosition:integer);
var
   lg, j : integer;
begin
   lg := length(VectoresElasticos);
   if aPosition > lg-1 then
     exit
   else if aPosition = lg-1 then begin
           Setlength(VectoresElasticos, lg -1);
           exit;
        end;
   for j := aPosition to lg-2 do
     VectoresElasticos[j] := VectoresElasticos[j+1];
   SetLength(VectoresElasticos, lg-1);
end;

Procedure TForm1.ReadFixesFile(filename: String);
var
  FL: TextFile;
  Cur: Integer;
  Procedure ReadLine;
  Var
    S: String;
    Ponto : TmyPoint;
    s1,s2,s3 : string;
  begin
    ReadLn(FL, S);
    If (S[1] <> ';') then
    begin
      s1 := Copy(S,7,14);
      s2 := Copy(S,22,14);
      s3 := Copy(S,1,5);
      Ponto.lat := StringToDouble(s1);
      Ponto.lon := StringToDouble(s2);
      Ponto := CoordToCart(Ponto);
      Fixes[Cur].Ponto := Ponto;
      Fixes[Cur].Nome := s3;
      Inc(Cur);
    end;
  end;
begin
  SetLength(Fixes, 6000);
  AssignFile(FL, 'datafiles\'+filename);
  Reset(FL);
  Cur := 0;
  While Not EOF(FL) do
  begin
    ReadLine;
  end;
end;

Procedure TForm1.ReadVorsFile(filename: String);
var
  FL: TextFile;
  Cur: Integer;
  Procedure ReadLine;
  Var
    S: String;
    Ponto : TmyPoint;
    s1,s2,s3 : string;
  begin
    ReadLn(FL, S);
    If (S[1] <> ';') then
    begin
      s1 := Copy(S,13,14);
      s2 := Copy(S,28,14);
      s3 := Copy(S,1,3);
      Ponto.lat := StringToDouble(s1);
      Ponto.lon := StringToDouble(s2);
      Ponto := CoordToCart(Ponto);
      Vors[Cur].Ponto := Ponto;
      Vors[Cur].Nome := s3;
      Inc(Cur);
    end;
  end;
begin
  SetLength(Vors, 300);
  AssignFile(FL, 'datafiles\'+filename);
  Reset(FL);
  Cur := 0;
  While Not EOF(FL) do
  begin
    ReadLine;
  end;
end;

procedure TForm1.Reset1Click(Sender: TObject);
begin
  zoom := 0;
  xLow :=-600;
  xHigh := 100;
  yLow := 2400;
  yHigh := 2800;
  tlx := 0;
  brx := radarWidth;
  tly := 0;
  bry := radarHeight;
  state := 0;
  CalculaPontos;
  PaintBox1.Invalidate;
end;

procedure TForm1.ResetVectors1Click(Sender: TObject);
begin
  SetLength(VectoresElasticos,0);
  CalculaPontos;
  PaintBox1.Invalidate;
end;

Procedure TForm1.ReadNDBsFile(filename: String);
var
  FL: TextFile;
  Cur: Integer;
  Procedure ReadLine;
  Var
    S: String;
    Ponto : TmyPoint;
    s1,s2,s3 : string;
  begin
    ReadLn(FL, S);
    If (S[1] <> ';') then
    begin
      s1 := Copy(S,15,14);
      s2 := Copy(S,30,14);
      s3 := Copy(S,1,3);
      Ponto.lat := StringToDouble(s1);
      Ponto.lon := StringToDouble(s2);
      Ponto := CoordToCart(Ponto);
      NDBs[Cur].Ponto := Ponto;
      NDBs[Cur].Nome := s3;
      Inc(Cur);
    end;
  end;
begin
  SetLength(NDBs, 400);
  AssignFile(FL,'datafiles\'+filename);
  Reset(FL);
  Cur := 0;
  While Not EOF(FL) do
  begin
    ReadLine;
  end;
end;

Procedure TForm1.ReadSectorFile(filename: String);
Var
  FL: TextFile;
  Cur: Integer;
  Procedure ReadLine;
  Var
    S: String;
    Ponto1, Ponto2, Ponto3, Ponto4, Cor: String;
    p1x, p1y, p2x, p2y : Double;
    Ponto : TmyPoint;
  begin
    ReadLn(FL, S);
    If (S[1] = 'N') and (S[1] <> ';') then
    begin
      Ponto1 := Copy(S, 1, 14);
      Ponto2 := Copy(S, 16, 14);
      Ponto3 := Copy(S, 31, 14);
      Ponto4 := Copy(S, 46, 14);
      Cor := Copy(S, 61, Length(S)-60);
      p1y := StringToDouble(Ponto1);
      p1x := StringToDouble(Ponto2);
      p2y := StringToDouble(Ponto3);
      p2x := StringToDouble(Ponto4);
      Ponto.lat := p1y;
      Ponto.lon := p1x;
      Mapa[Cur].Ponto1 := CoordToCart(Ponto);
      Ponto.lat := p2y;
      Ponto.lon := p2x;
      Mapa[Cur].Ponto2 := CoordToCart(Ponto);
      if (cor = 'c_coast') then Mapa[Cur].Color := c_coast
      else if (cor = 'c_maroon') then Mapa[Cur].Color := c_maroon
      else if (cor = 'c_TWR') then Mapa[Cur].Color := c_TWR
      else if (cor = 'c_TMA') then Mapa[Cur].Color := c_TMA
      else if (cor = 'c_RVA') then Mapa[Cur].Color := c_RVA
      else Mapa[Cur].Color := clSilver;
      Inc(Cur);
    end;
  end;
begin
  SetLength(Mapa, 40000);
  AssignFile(FL, 'datafiles\'+filename);
  Reset(FL);
  Cur := 0;
  While Not EOF(FL) do
  begin
    ReadLine;
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  Self.DoubleBuffered := True;
  zoom := 0;
  xLow :=-600;
  xHigh := 100;
  yLow := 2400;
  yHigh := 2800;
  tlx := 0;
  brx := radarWidth;
  tly := 0;
  bry := radarHeight;
  state := 0;
  showFixes := True;
  showVORs := True;
  showNDBs := False;
  ReadSectorFile('portugal.sct');
  ReadFixesFile('fixes-pt.txt');
  ReadVorsFile('vors-pt.txt');
  ReadNDBsFile('ndbs.txt');
  CalculaPontos;
end;

procedure TForm1.FormShow(Sender: TObject);
begin
  CenterForm(Form1);
end;

procedure TForm1.CalculaPontos();
var
  F: Integer;
  P1Xd, P1Yd, P2Xd, P2Yd: double;
  len : Integer;
begin
  for F := 0 to Length(Mapa) - 1 do
  begin
    P1Xd := Mapa[F].Ponto1.X;
    P1Yd := Mapa[F].Ponto1.Y;
    P2Xd := Mapa[F].Ponto2.X;
    P2Yd := Mapa[F].Ponto2.Y;
    Mapa[F].Ponto1.Xi := mapW2SxLin(P1Xd);
    Mapa[F].Ponto1.Yi := mapW2SyLin(P1Yd);
    Mapa[F].Ponto2.Xi := mapW2SxLin(P2Xd);
    Mapa[F].Ponto2.Yi := mapW2SyLin(P2Yd);
  end;
  for F := 0 to Length(Fixes) - 1 do
  begin
    P1Xd := Fixes[F].Ponto.X;
    P1Yd := Fixes[F].Ponto.Y;
    Fixes[F].Ponto.Xi := mapW2SxLin(P1Xd);
    Fixes[F].Ponto.Yi := mapW2SyLin(P1Yd);
  end;
  for F := 0 to Length(VORs) - 1 do
  begin
    P1Xd := VORs[F].Ponto.X;
    P1Yd := VORs[F].Ponto.Y;
    VORs[F].Ponto.Xi := mapW2SxLin(P1Xd);
    VORs[F].Ponto.Yi := mapW2SyLin(P1Yd);
  end;
  for F := 0 to Length(NDBs) - 1 do
  begin
    P1Xd := NDBs[F].Ponto.X;
    P1Yd := NDBs[F].Ponto.Y;
    NDBs[F].Ponto.Xi := mapW2SxLin(P1Xd);
    NDBs[F].Ponto.Yi := mapW2SyLin(P1Yd);
  end;
  len := Length(VectoresElasticos);
  for F := 0 to len - 1 do
  begin
    P1Xd := VectoresElasticos[F].PontoInicial.X;
    P1Yd := VectoresElasticos[F].PontoInicial.Y;
    VectoresElasticos[F].PontoInicial.Xi := mapW2SxLin(P1Xd);
    VectoresElasticos[F].PontoInicial.Yi := mapW2SyLin(P1Yd);
    P1Xd := VectoresElasticos[F].PontoFinal.X;
    P1Yd := VectoresElasticos[F].PontoFinal.Y;
    VectoresElasticos[F].PontoFinal.Xi := mapW2SxLin(P1Xd);
    VectoresElasticos[F].PontoFinal.Yi := mapW2SyLin(P1Yd);
  end;
end;

procedure DesenhaSegmentoAidsTag(Canvas : TCanvas; auxSeg : TVectorElastico);
var
  x,y : integer;
  len : integer;
begin
      x := auxSeg.PontoFinal.Xi;
      y := auxSeg.PontoFinal.Yi;
      if auxSeg.Distance > 0 then
        begin
          With Canvas do
            begin
              if auxSeg.isSelected = True then
                Brush.Color := clYellow
              else
                Brush.Color := TColor($555555);
              FillRect(Rect(x,y,x+labelWidth,y+labelHeight));
              Brush.Color :=TColor($333333);
              FillRect(Rect(x+1,y+1,x+labelWidth-1,y+labelHeight-1));
              Font.Size := 8;
              Font.Name := 'Consolas';
              Font.Color := clWhite;
              len := TextWidth(FloatToStr(Round(auxSeg.Distance))+'nm');
              len := Round((labelWidth-len)/2);
              TextOut(x+len,y+1,FloatToStr(Round(auxSeg.Distance))+'nm');
              len := TextWidth(FloatToStr(auxSeg.Heading)+'º/'+FloatToStr(auxSeg.CoHeading)+'º');
              len := Round((labelWidth-len)/2);
              TextOut(x+len,y+15,FloatToStr(auxSeg.Heading)+'º/'+FloatToStr(auxSeg.CoHeading)+'º');
            end;
        end;
end;

// DESENHA MAPA
procedure TForm1.DesenharMapa(Sender: TObject);
Var
  F: Integer;
  P1X, P1Y, P2X, P2Y: Integer;
  Fix : String;
  DestCanvas : TCanvas;
  BMP : TBitmap;
  len : Integer;
  I: Integer;
begin
  Bmp:=TBitmap.Create;
  Bmp.Width:=PaintBox1.Width;
  Bmp.Height:=PaintBox1.Height;
  DestCanvas:=Bmp.Canvas;
  DestCanvas.Brush.Color := clBlack;
  DestCanvas.FillRect(PaintBox1.Canvas.ClipRect);
  if State <> 1 then
  begin
    For F := 0 to Length(Mapa) - 1 do
    begin
      P1X := Mapa[F].Ponto1.Xi;
      P1Y := Mapa[F].Ponto1.Yi;
      P2X := Mapa[F].Ponto2.Xi;
      P2Y := Mapa[F].Ponto2.Yi;
      DestCanvas.Pen.Color := Mapa[F].Color;
      DestCanvas.MoveTo(P1X, P1Y);
      DestCanvas.LineTo(P2X, P2Y);
    end;
  end;
  // DESENHA FIXES
  if showFixes then
  begin
  With DestCanvas do
  begin
        Pen.Color := clGreen;
        Font.Color := clGreen;
        Font.Size := 8;
        Font.Name := 'Consolas';
  end;
  for F := 0 to Length(Fixes) - 1 do
    begin
      P1X := Fixes[F].Ponto.Xi;
      P1Y := Fixes[F].Ponto.Yi;
      Fix := Fixes[F].Nome;
      With DestCanvas do
      begin
        If State<>1 then TextOut(P1X-14, P1Y-15, Fix);
        MoveTo(P1X,P1Y-4);
        LineTo(P1X+4,P1Y+4);
        LineTo(P1X-4,P1Y+4);
        LineTo(P1X,P1Y-4);
      end;
    end;
  end;
  // DESENHA VORS
  if showVors then
  begin
  With DestCanvas do
  begin
        Pen.Color := clBlue;
        Font.Color := clBlue;
        Font.Size := 8;
        Font.Name := 'Consolas';
  end;
  for F := 0 to Length(Vors) - 1 do
    begin
      P1X := Vors[F].Ponto.Xi;
      P1Y := Vors[F].Ponto.Yi;
      Fix := Vors[F].Nome;
      With DestCanvas do
      begin
        If State<>1 then TextOut(P1X-9, P1Y-15, Fix);
        MoveTo(P1X,P1Y-4);
        LineTo(P1X+4,P1Y+4);
        LineTo(P1X-4,P1Y+4);
        LineTo(P1X,P1Y-4);
      end;
    end;
  end;
  // DESENHA NDBs
  if showNDBs then
  begin
  With DestCanvas do
  begin
        Pen.Color := clRed;
        Font.Color := clRed;
        Font.Size := 8;
        Font.Name := 'Consolas';
  end;
  for F := 0 to Length(NDBs) - 1 do
    begin
      P1X := NDBs[F].Ponto.Xi;
      P1Y := NDBs[F].Ponto.Yi;
      Fix := NDBs[F].Nome;
      With DestCanvas do
      begin
        If State<>1 then TextOut(P1X-9, P1Y-15, Fix);
        MoveTo(P1X,P1Y-4);
        LineTo(P1X+4,P1Y+4);
        LineTo(P1X-4,P1Y+4);
        LineTo(P1X,P1Y-4);
      end;
    end;
  end;
  // Desenha Segmentos de Recta
  len := Length(VectoresElasticos);
  if len > 0 then
    begin
      for I := 0 to len - 1 do
        begin
          With DestCanvas Do
            begin
              if state <> 1 then
                begin
                  Pen.Color := clWhite;
                  MoveTo(VectoresElasticos[i].PontoInicial.Xi,VectoresElasticos[i].PontoInicial.Yi);
                  LineTo(VectoresElasticos[i].PontoFinal.Xi,VectoresElasticos[i].PontoFinal.Yi);
                  DesenhaSegmentoAidsTag(DestCanvas, VectoresElasticos[i]);
                end;
            end;
        end;
    end;
  BitBlt(PaintBox1.Canvas.Handle,0,0,Bmp.Width,Bmp.Height,bmp.Canvas.Handle,0,0,SRCCOPY);
  Bmp.Free;
end;

// MOUSEWHEEL ZOOM
procedure TForm1.FormMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint;
  var Handled: Boolean);
begin
  if WheelDelta > 0 then Zoom := 0.05
  else Zoom := -0.05;
  xDelta := (xHigh - xLow) * Zoom;
  yDelta := (yHigh - yLow) * Zoom;
  xLow := xLow + xDelta;
  xHigh := xHigh - xDelta;
  yLow := yLow + yDelta;
  yHigh := yHigh - yDelta;
  CalculaPontos;
  PaintBox1.Invalidate;
  Handled:=True;
end;

// MOUSE DOWN
procedure TForm1.PaintBox1MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  Rect : TRect;
begin
  Rect := GetClientRect;
  Rect.TopLeft := ClientToScreen(Rect.TopLeft);
  Rect.BottomRight := ClientToScreen(Rect.BottomRight);
  ClipCursor(@Rect);
  startx := mapS2WxLin(X);
  starty := mapS2WyLin(Y);
  startxi := X;
  startyi := Y;
  delLabel := detectLabel(x,y);
  if Button = mbMiddle then
    begin
      lastxi := X;
      lastyi := Y;
      state := 2;
      if (delLabel >= 0) then state := 3;
    end;
  if Button = mbRight then
    begin
      state := 1;
    end;
  if Button = mbLeft then
    begin
      state := 4;
    end;
end;

// MOUSE MOVE
procedure TForm1.PaintBox1MouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
var
  penmode : TPenMode;
  curX, curY : Double;
  curPoint : TmyPoint;
begin
  curX := mapS2WxLin(X);
  curY := mapS2WyLin(Y);
  curPoint.X := curX;
  curPoint.Y := curY;
  curPoint := CartToCoord(curPoint);
  StatusBar1.Panels[0].Text := HumanCoord(curPoint, false);
  StatusBar1.Panels[1].Text := HumanCoord(curPoint, true);
  if state = 2 then
  begin
    with PaintBox1.Canvas do
    begin
      Pen.Color := clWhite;
      penmode := Pen.Mode;
      Pen.Mode := pmXOR;
      MoveTo(startxi,startyi);
      LineTo(lastxi,lastyi);
      Pen.Mode := pmXOR;
      MoveTo(startxi,startyi);
      LineTo(x,y);
      Pen.Mode := penmode;
    end;
    lastxi := X;
    lastyi := Y;
  end;
  if state = 1 then
  begin
    lastx := curX;
    lasty := curY;
    lastxi := X;
    lastyi := Y;
    deltax := lastx - startx;
    deltay := lasty - starty;
    xLow := xLow - deltax;
    xHigh := xHigh - deltax;
    yLow := yLow - deltay;
    yHigh := yHigh - deltay;
    Screen.Cursor := crSizeAll;
    CalculaPontos;
    PaintBox1.Invalidate;
  end;
  if state = 3 then
    begin
      lastxi := X;
      lastyi := Y;
    end;
end;

// MOUSE UP
procedure TForm1.PaintBox1MouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  penmode : TPenMode;
  tempPonto,tempPonto2 : TmyPoint;
  len : integer;
  posToMiddleX, posToMiddleY : Integer;
  Distance, Heading, CoHeading : Integer;
begin
  if state = 2 then
    begin
      with PaintBox1.Canvas do
        begin
          Pen.Color := clWhite;
          penmode := Pen.Mode;
          Pen.Mode := pmXOR;
          MoveTo(startxi,startyi);
          LineTo(lastxi,lastyi);
          Pen.Mode := pmXOR;
          MoveTo(startxi,startyi);
          LineTo(lastxi,lastyi);
          Pen.Mode := penmode;
        end;
      lastx := mapS2WxLin(X);
      lasty := mapS2WyLin(Y);
      tempPonto.X := lastx;
      tempPonto.Y := lasty;
      tempPonto.Xi := lastxi;
      tempPonto.Yi := lastyi;
      tempPonto := CartToCoord(tempPonto);
      tempPonto2.X := startx;
      tempPonto2.Y := starty;
      tempPonto2 := CartToCoord(tempPonto2);
      len := Length(VectoresElasticos);
      SetLength(VectoresElasticos,len+1);
      distance := calculateDistance(tempPonto2, tempPonto);
      heading := round(calculateBearing(tempPonto2, tempPonto)) + 4;
      heading := (heading+360) mod 360;
      if heading > 180 then coheading := heading - 180
      else coheading := heading + 180;
      VectoresElasticos[len].PontoInicial := tempPonto2;
      VectoresElasticos[len].PontoFinal := tempPonto;
      VectoresElasticos[len].Distance := distance;
      VectoresElasticos[len].Heading := Heading;
      VectoresElasticos[len].CoHeading := CoHeading;
      VectoresElasticos[len].isSelected := False;
      DesenhaSegmentoAidsTag(PaintBox1.Canvas, VectoresElasticos[len]);
      state := 0;
    end;
  if state = 1 then
    begin
      if (startxi = x) and (startyi = y) then
        begin
          posToMiddleX := X - Round(radarWidth/2);
          posToMiddleY := Y - Round(radarHeight/2);
          startx := mapS2WxLin(Round(radarWidth/2));
          starty := mapS2WyLin(Round(radarHeight/2));
          lastx := mapS2WxLin(Round(radarWidth/2)-posToMiddleX);
          lasty := mapS2WyLin(Round(radarHeight/2)-posToMiddleY);
        end
        else
        begin
          lastx := mapS2WxLin(X);
          lasty := mapS2WyLin(Y);
        end;
      deltax := lastx - startx;
      deltay := lasty - starty;
      xLow := xLow - deltax;
      xHigh := xHigh - deltax;
      yLow := yLow - deltay;
      yHigh := yHigh - deltay;
      Screen.Cursor := crDefault;
      CalculaPontos;
      PaintBox1.Invalidate;
      state := 0;
  end;
  if state = 3 then
    begin
      lastxi := X;
      lastyi := Y;
      if (startxi = lastxi) and (startyi = lastyi) then
        begin
          DeleteElement(delLabel);
          CalculaPontos;
          PaintBox1.Invalidate;
        end;
      state := 0;
    end;
  if state = 4 then
    begin
      if (startxi = x) and (startyi = y) then
        begin
          if delLabel >= 0 then VectoresElasticos[delLabel].isSelected := Not VectoresElasticos[delLabel].isSelected;
          CalculaPontos;
          PaintBox1.Invalidate;
          state := 0;
        end;
    end;
  ClipCursor(nil);
end;

initialization
  DecimalSeparator := '.';

end.

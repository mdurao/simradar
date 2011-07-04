object Form1: TForm1
  Left = 0
  Top = 0
  AutoSize = True
  Caption = 'Form1'
  ClientHeight = 1001
  ClientWidth = 1800
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  Menu = MainMenu1
  OldCreateOrder = False
  OnCreate = FormCreate
  OnMouseWheel = FormMouseWheel
  OnPaint = DesenharMapa
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object PaintBox1: TPaintBox
    Left = 0
    Top = 0
    Width = 1800
    Height = 1000
    Color = clSilver
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Consolas'
    Font.Style = []
    ParentColor = False
    ParentFont = False
    OnMouseDown = PaintBox1MouseDown
    OnMouseMove = PaintBox1MouseMove
    OnMouseUp = PaintBox1MouseUp
    OnPaint = DesenharMapa
  end
  object StatusBar1: TStatusBar
    Left = 0
    Top = 982
    Width = 1800
    Height = 19
    Panels = <
      item
        BiDiMode = bdLeftToRight
        ParentBiDiMode = False
        Text = 'Lat'
        Width = 100
      end
      item
        Text = 'Lon'
        Width = 100
      end>
  end
  object Timer1: TTimer
    Left = 24
    Top = 24
  end
  object MainMenu1: TMainMenu
    Left = 64
    Top = 24
    object Hello1: TMenuItem
      Caption = 'Radar'
      object Reset1: TMenuItem
        Caption = 'Reset View'
        OnClick = Reset1Click
      end
      object ResetVectors1: TMenuItem
        Caption = 'Reset Vectors'
        OnClick = ResetVectors1Click
      end
    end
  end
end

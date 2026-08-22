' ================================================================================
' FIGURE 1: HIGH-LEVEL LAYERED SYSTEM ARCHITECTURE (MS WORD VBA SCRIPT)
' ================================================================================
' Run this in Word (Alt + F11 -> Insert -> Module -> Paste -> F5)
' ================================================================================

Option Explicit

Sub GenerateFigure1_LayeredArchitecture()
    Dim doc As Document
    Set doc = ActiveDocument
    
    With doc.PageSetup
        .PaperSize = wdPaperA4
        .TopMargin = 54
        .BottomMargin = 54
        .LeftMargin = 54
        .RightMargin = 54
    End With
    
    Application.ScreenUpdating = False
    
    Dim curRng As Range
    Set curRng = doc.Paragraphs.Last.Range
    
    Dim baseY As Single
    baseY = 60
    
    ' Layer 1: Presentation Layer
    AddBox doc, curRng, 54, baseY, 486, 75, "", RGB(236, 253, 245), RGB(5, 150, 105), RGB(6, 95, 70), True, 10
    AddBox doc, curRng, 64, baseY + 6, 466, 18, "1. Presentation Layer (Flutter 3.x Multi-Platform UI)", RGB(209, 250, 229), RGB(5, 150, 105), RGB(6, 95, 70), True, 9
    AddBox doc, curRng, 64, baseY + 28, 72, 38, "Dashboard &" & vbCrLf & "Calorie Ring", RGB(255, 255, 255), RGB(5, 150, 105), RGB(15, 23, 42), False, 7.5
    AddBox doc, curRng, 142, baseY + 28, 72, 38, "Quick AI Meal" & vbCrLf & "Logger", RGB(255, 255, 255), RGB(5, 150, 105), RGB(15, 23, 42), False, 7.5
    AddBox doc, curRng, 220, baseY + 28, 74, 38, "AI Clinical" & vbCrLf & "Coach & Voice", RGB(255, 255, 255), RGB(5, 150, 105), RGB(15, 23, 42), False, 7.5
    AddBox doc, curRng, 300, baseY + 28, 72, 38, "Ramadan Fast" & vbCrLf & "Tracker", RGB(255, 255, 255), RGB(5, 150, 105), RGB(15, 23, 42), False, 7.5
    AddBox doc, curRng, 378, baseY + 28, 72, 38, "Family Multi" & vbCrLf & "Profile Hub", RGB(255, 255, 255), RGB(5, 150, 105), RGB(15, 23, 42), False, 7.5
    AddBox doc, curRng, 456, baseY + 28, 74, 38, "Live Clinic" & vbCrLf & "Finder (OSM)", RGB(255, 255, 255), RGB(5, 150, 105), RGB(15, 23, 42), False, 7.5

    AddArrow doc, curRng, 297, baseY + 75, 297, baseY + 95, RGB(5, 150, 105)

    ' Layer 2: Controller Layer
    baseY = baseY + 95
    AddBox doc, curRng, 54, baseY, 486, 60, "", RGB(239, 246, 255), RGB(37, 99, 235), RGB(30, 64, 175), True, 10
    AddBox doc, curRng, 64, baseY + 5, 466, 16, "2. Controller & State Management Layer", RGB(219, 234, 254), RGB(37, 99, 235), RGB(30, 64, 175), True, 8.5
    AddBox doc, curRng, 64, baseY + 24, 110, 30, "FamilyViewModel" & vbCrLf & "(Profile State)", RGB(255, 255, 255), RGB(37, 99, 235), RGB(15, 23, 42), False, 7.5
    AddBox doc, curRng, 182, baseY + 24, 110, 30, "RamadanController" & vbCrLf & "(Fasting Engine)", RGB(255, 255, 255), RGB(37, 99, 235), RGB(15, 23, 42), False, 7.5
    AddBox doc, curRng, 300, baseY + 24, 110, 30, "SyncService" & vbCrLf & "(Background Queue)", RGB(255, 255, 255), RGB(37, 99, 235), RGB(15, 23, 42), False, 7.5
    AddBox doc, curRng, 418, baseY + 24, 112, 30, "ReminderManager" & vbCrLf & "(Adaptive Streaks)", RGB(255, 255, 255), RGB(37, 99, 235), RGB(15, 23, 42), False, 7.5

    AddArrow doc, curRng, 297, baseY + 60, 297, baseY + 80, RGB(37, 99, 235)

    ' Layer 3: Backend API Gateway
    baseY = baseY + 80
    AddBox doc, curRng, 54, baseY, 486, 60, "", RGB(253, 244, 255), RGB(192, 38, 211), RGB(134, 25, 143), True, 10
    AddBox doc, curRng, 64, baseY + 5, 466, 16, "3. Backend API Gateway (FastAPI Python 3.11+)", RGB(245, 208, 254), RGB(192, 38, 211), RGB(134, 25, 143), True, 8.5
    AddBox doc, curRng, 64, baseY + 24, 110, 30, "/api/v1/meals" & vbCrLf & "(Search & Barcode)", RGB(255, 255, 255), RGB(192, 38, 211), RGB(15, 23, 42), False, 7.5
    AddBox doc, curRng, 182, baseY + 24, 110, 30, "/api/v1/coach" & vbCrLf & "(Chat & Triage)", RGB(255, 255, 255), RGB(192, 38, 211), RGB(15, 23, 42), False, 7.5
    AddBox doc, curRng, 300, baseY + 24, 110, 30, "/api/v1/family" & vbCrLf & "(Dependent Store)", RGB(255, 255, 255), RGB(192, 38, 211), RGB(15, 23, 42), False, 7.5
    AddBox doc, curRng, 418, baseY + 24, 112, 30, "/api/v1/meals/report" & vbCrLf & "(ReportLab PDF)", RGB(255, 255, 255), RGB(192, 38, 211), RGB(15, 23, 42), False, 7.5

    AddArrow doc, curRng, 170, baseY + 60, 170, baseY + 80, RGB(217, 119, 6)
    AddArrow doc, curRng, 420, baseY + 60, 420, baseY + 80, RGB(71, 85, 105)

    ' Layer 4: AI Services & Persistence Layer
    baseY = baseY + 80
    AddBox doc, curRng, 54, baseY, 235, 95, "", RGB(255, 251, 235), RGB(217, 119, 6), RGB(146, 64, 14), True, 9.5
    AddBox doc, curRng, 60, baseY + 5, 223, 16, "4. AI & Microservices", RGB(254, 243, 199), RGB(217, 119, 6), RGB(146, 64, 14), True, 8
    AddBox doc, curRng, 60, baseY + 24, 108, 30, "Gemini Multi-Key" & vbCrLf & "Failover Pool", RGB(255, 255, 255), RGB(217, 119, 6), RGB(15, 23, 42), False, 7.5
    AddBox doc, curRng, 175, baseY + 24, 108, 30, "OpenFoodFacts" & vbCrLf & "Barcode API", RGB(255, 255, 255), RGB(217, 119, 6), RGB(15, 23, 42), False, 7.5
    AddBox doc, curRng, 60, baseY + 58, 108, 30, "OpenStreetMap" & vbCrLf & "Overpass API", RGB(255, 255, 255), RGB(217, 119, 6), RGB(15, 23, 42), False, 7.5
    AddBox doc, curRng, 175, baseY + 58, 108, 30, "Aladhan Prayer" & vbCrLf & "Timings API", RGB(255, 255, 255), RGB(217, 119, 6), RGB(15, 23, 42), False, 7.5

    AddBox doc, curRng, 305, baseY, 235, 95, "", RGB(248, 250, 252), RGB(71, 85, 105), RGB(30, 41, 59), True, 9.5
    AddBox doc, curRng, 311, baseY + 5, 223, 16, "5. Persistence Layer", RGB(226, 232, 240), RGB(71, 85, 105), RGB(30, 41, 59), True, 8
    AddBox doc, curRng, 311, baseY + 26, 223, 30, "SQLite Local Database (Offline Cache & Sync Queue)", RGB(255, 255, 255), RGB(71, 85, 105), RGB(15, 23, 42), False, 7.5
    AddBox doc, curRng, 311, baseY + 60, 223, 30, "Supabase PostgreSQL (JWT Auth & Row Level Security)", RGB(224, 231, 255), RGB(67, 56, 202), RGB(49, 46, 129), True, 7.5

    AddCaption doc, "Figure 1", "High-Level Layered Architecture Diagram of the NutriSense System."
    Application.ScreenUpdating = True
    MsgBox "Figure 1 Generated Successfully!", vbInformation, "NutriSense"
End Sub

Function AddBox(doc As Document, anchorRng As Range, leftPos As Single, topPos As Single, w As Single, h As Single, _
                txt As String, fillRGB As Long, borderRGB As Long, textRGB As Long, _
                Optional isBold As Boolean = False, Optional fSize As Single = 8.5, _
                Optional shapeType As MsoAutoShapeType = msoShapeRoundedRectangle) As Shape
    Dim shp As Shape
    Set shp = doc.Shapes.AddShape(shapeType, leftPos, topPos, w, h, Anchor:=anchorRng)
    With shp
        .RelativeHorizontalPosition = wdRelativeHorizontalPositionPage
        .RelativeVerticalPosition = wdRelativeVerticalPositionPage
        .Left = leftPos
        .Top = topPos
        .Fill.Solid
        .Fill.ForeColor.RGB = fillRGB
        .Line.ForeColor.RGB = borderRGB
        .Line.Weight = 1.2
        With .TextFrame
            .TextRange.Text = txt
            .TextRange.Font.Name = "Calibri"
            .TextRange.Font.Size = fSize
            .TextRange.Font.Color = textRGB
            .TextRange.Font.Bold = isBold
            .TextRange.ParagraphFormat.Alignment = wdAlignParagraphCenter
            .MarginLeft = 3
            .MarginRight = 3
            .MarginTop = 2
            .MarginBottom = 2
        End With
    End With
    Set AddBox = shp
End Function

Function AddArrow(doc As Document, anchorRng As Range, startX As Single, startY As Single, endX As Single, endY As Single, _
                  lineRGB As Long, Optional isDashed As Boolean = False) As Shape
    Dim shp As Shape
    Set shp = doc.Shapes.AddLine(startX, startY, endX, endY, Anchor:=anchorRng)
    With shp
        .RelativeHorizontalPosition = wdRelativeHorizontalPositionPage
        .RelativeVerticalPosition = wdRelativeVerticalPositionPage
        With .Line
            .ForeColor.RGB = lineRGB
            .Weight = 1.5
            .EndArrowheadStyle = msoArrowheadTriangle
            .EndArrowheadLength = msoArrowheadLengthMedium
            .EndArrowheadWidth = msoArrowheadWidthMedium
            If isDashed Then
                .DashStyle = msoLineDash
            End If
        End With
    End With
    Set AddArrow = shp
End Function

Sub AddCaption(doc As Document, figureTitle As String, desc As String)
    Dim p As Paragraph
    Set p = doc.Paragraphs.Add
    p.Range.Text = vbCrLf & vbCrLf & vbCrLf & vbCrLf & vbCrLf & vbCrLf & vbCrLf & vbCrLf & vbCrLf & vbCrLf & _
                   vbCrLf & vbCrLf & vbCrLf & vbCrLf & vbCrLf & vbCrLf & vbCrLf & vbCrLf & _
                   figureTitle & ": " & desc & vbCrLf
    p.Range.Font.Name = "Calibri"
    p.Range.Font.Size = 10
    p.Range.Font.Italic = True
    p.Range.Font.Color = RGB(51, 65, 85)
    p.Range.ParagraphFormat.Alignment = wdAlignParagraphCenter
End Sub

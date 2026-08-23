' ================================================================================
' FIGURE 8: PHYSICAL & CLOUD DEPLOYMENT DIAGRAM (MS WORD VBA SCRIPT)
' ================================================================================
' Run this in Word (Alt + F11 -> Insert -> Module -> Paste -> F5)
' ================================================================================

Option Explicit

Sub GenerateFigure8_DeploymentDiagram()
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
    
    ' Node 1: Client Devices
    AddBox doc, curRng, 54, baseY, 486, 65, "", RGB(239, 246, 255), RGB(37, 99, 235), RGB(30, 64, 175), True, 9.5
    AddBox doc, curRng, 64, baseY + 5, 466, 16, "1. Client Layer (User Hardware Mobile Nodes)", RGB(219, 234, 254), RGB(37, 99, 235), RGB(30, 64, 175), True, 8.5
    AddBox doc, curRng, 64, baseY + 24, 225, 32, "Android Device (NutriSense APK, SQLite DB, Google Health Connect)", RGB(255, 255, 255), RGB(37, 99, 235), RGB(15, 23, 42), False, 7.5
    AddBox doc, curRng, 305, baseY + 24, 225, 32, "iOS Device (NutriSense IPA, SQLite DB, Apple HealthKit Bridge)", RGB(255, 255, 255), RGB(37, 99, 235), RGB(15, 23, 42), False, 7.5

    AddArrow doc, curRng, 297, baseY + 65, 297, baseY + 85, RGB(37, 99, 235)

    ' Node 2: Backend Cloud Container
    baseY = baseY + 85
    AddBox doc, curRng, 54, baseY, 486, 65, "", RGB(236, 253, 245), RGB(5, 150, 105), RGB(6, 95, 70), True, 9.5
    AddBox doc, curRng, 64, baseY + 5, 466, 16, "2. Application Server (FastAPI Cloud Container on Render / GCP)", RGB(209, 250, 229), RGB(5, 150, 105), RGB(6, 95, 70), True, 8.5
    AddBox doc, curRng, 64, baseY + 24, 466, 32, "Docker Container (Python 3.11 + Uvicorn ASGI Server, Gemini Multi-Key Failover Pool, ReportLab Engine)", RGB(255, 255, 255), RGB(5, 150, 105), RGB(15, 23, 42), False, 7.5

    AddArrow doc, curRng, 150, baseY + 65, 150, baseY + 85, RGB(192, 38, 211)
    AddArrow doc, curRng, 297, baseY + 65, 297, baseY + 85, RGB(217, 119, 6)
    AddArrow doc, curRng, 440, baseY + 65, 440, baseY + 85, RGB(71, 85, 105)

    ' Nodes 3, 4, 5: Cloud Database, AI Infrastructure, Third Party Services
    baseY = baseY + 85
    AddBox doc, curRng, 54, baseY, 155, 100, "", RGB(253, 244, 255), RGB(192, 38, 211), RGB(134, 25, 143), True, 9
    AddBox doc, curRng, 60, baseY + 5, 143, 16, "3. Supabase Cloud", RGB(245, 208, 254), RGB(192, 38, 211), RGB(134, 25, 143), True, 8
    AddBox doc, curRng, 60, baseY + 25, 143, 30, "Supabase Auth" & vbCrLf & "(JWT Session Validation)", RGB(255, 255, 255), RGB(192, 38, 211), RGB(15, 23, 42), False, 7.5
    AddBox doc, curRng, 60, baseY + 60, 143, 30, "PostgreSQL 15 DB" & vbCrLf & "(Row Level Security RLS)", RGB(224, 231, 255), RGB(67, 56, 202), RGB(49, 46, 129), True, 7.5

    AddBox doc, curRng, 220, baseY, 155, 100, "", RGB(255, 251, 235), RGB(217, 119, 6), RGB(146, 64, 14), True, 9
    AddBox doc, curRng, 226, baseY + 5, 143, 16, "4. Google AI Cloud", RGB(254, 243, 199), RGB(217, 119, 6), RGB(146, 64, 14), True, 8
    AddBox doc, curRng, 226, baseY + 25, 143, 30, "Gemini API Endpoint" & vbCrLf & "(gemini-2.5/3.6-flash)", RGB(255, 255, 255), RGB(217, 119, 6), RGB(15, 23, 42), False, 7.5
    AddBox doc, curRng, 226, baseY + 60, 143, 30, "Multi-Key Free Tier" & vbCrLf & "Round-Robin Rotator", RGB(255, 255, 255), RGB(217, 119, 6), RGB(15, 23, 42), False, 7.5

    AddBox doc, curRng, 385, baseY, 155, 100, "", RGB(248, 250, 252), RGB(71, 85, 105), RGB(30, 41, 59), True, 9
    AddBox doc, curRng, 391, baseY + 5, 143, 16, "5. Web Services", RGB(226, 232, 240), RGB(71, 85, 105), RGB(30, 41, 59), True, 8
    AddBox doc, curRng, 391, baseY + 25, 143, 20, "OpenStreetMap Overpass", RGB(255, 255, 255), RGB(71, 85, 105), RGB(15, 23, 42), False, 7
    AddBox doc, curRng, 391, baseY + 48, 143, 20, "Aladhan Prayer Timings", RGB(255, 255, 255), RGB(71, 85, 105), RGB(15, 23, 42), False, 7
    AddBox doc, curRng, 391, baseY + 71, 143, 20, "OpenFoodFacts Barcode", RGB(255, 255, 255), RGB(71, 85, 105), RGB(15, 23, 42), False, 7

    AddCaption doc, "Figure 8", "Physical and Cloud Deployment Diagram across Client Devices, FastAPI Cloud, Supabase and Google Gemini."
    Application.ScreenUpdating = True
    MsgBox "Figure 8 Generated Successfully!", vbInformation, "NutriSense"
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

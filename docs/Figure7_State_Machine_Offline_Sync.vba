' ================================================================================
' FIGURE 7: STATE MACHINE - OFFLINE SYNC (MS WORD VBA SCRIPT)
' ================================================================================
' Run this in Word (Alt + F11 -> Insert -> Module -> Paste -> F5)
' ================================================================================

Option Explicit

Sub GenerateFigure7_StateSyncDiagram()
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
    
    AddBox doc, curRng, 240, baseY, 114, 25, "Application Launch", RGB(236, 253, 245), RGB(5, 150, 105), RGB(6, 95, 70), True, 8, msoShapeOval
    AddArrow doc, curRng, 297, baseY + 25, 297, baseY + 45, RGB(5, 150, 105)

    baseY = baseY + 45
    AddBox doc, curRng, 210, baseY, 174, 30, "State: Idle / Waiting for Action", RGB(239, 246, 255), RGB(37, 99, 235), RGB(30, 64, 175), True, 8
    AddArrow doc, curRng, 297, baseY + 30, 297, baseY + 50, RGB(37, 99, 235)

    baseY = baseY + 50
    AddBox doc, curRng, 210, baseY, 174, 28, "Action: User Logs Meal / Water", RGB(241, 245, 249), RGB(71, 85, 105), RGB(15, 23, 42), False, 8
    AddArrow doc, curRng, 297, baseY + 28, 297, baseY + 48, RGB(71, 85, 105)

    baseY = baseY + 48
    AddBox doc, curRng, 230, baseY, 134, 40, "Check:" & vbCrLf & "Is Network Online?", RGB(254, 243, 199), RGB(217, 119, 6), RGB(146, 64, 14), True, 8, msoShapeDiamond

    ' Branch Left: Online Path
    AddArrow doc, curRng, 230, baseY + 20, 130, baseY + 60, RGB(5, 150, 105)
    AddBox doc, curRng, 110, baseY + 18, 55, 14, "Yes: Online", RGB(255, 255, 255), RGB(255, 255, 255), RGB(5, 150, 105), True, 7

    AddBox doc, curRng, 54, baseY + 60, 150, 30, "Write to SQLite" & vbCrLf & "(is_synced = true)", RGB(236, 253, 245), RGB(5, 150, 105), RGB(6, 95, 70), False, 7.5
    AddArrow doc, curRng, 129, baseY + 90, 129, baseY + 115, RGB(5, 150, 105)

    AddBox doc, curRng, 54, baseY + 115, 150, 30, "Send POST Request" & vbCrLf & "to Supabase Cloud DB", RGB(236, 253, 245), RGB(5, 150, 105), RGB(6, 95, 70), False, 7.5

    ' Branch Right: Offline Path
    AddArrow doc, curRng, 364, baseY + 20, 460, baseY + 60, RGB(219, 39, 119)
    AddBox doc, curRng, 430, baseY + 18, 55, 14, "No: Offline", RGB(255, 255, 255), RGB(255, 255, 255), RGB(219, 39, 119), True, 7

    AddBox doc, curRng, 390, baseY + 60, 150, 30, "Write to SQLite" & vbCrLf & "(is_synced = false)", RGB(253, 242, 248), RGB(219, 39, 119), RGB(157, 23, 77), False, 7.5
    AddArrow doc, curRng, 465, baseY + 90, 465, baseY + 115, RGB(219, 39, 119)

    AddBox doc, curRng, 390, baseY + 115, 150, 30, "Notify User & Listen to" & vbCrLf & "Connectivity Stream", RGB(255, 251, 235), RGB(217, 119, 6), RGB(146, 64, 14), False, 7.5
    AddArrow doc, curRng, 465, baseY + 145, 465, baseY + 170, RGB(217, 119, 6)

    AddBox doc, curRng, 390, baseY + 170, 150, 35, "Network Restored:" & vbCrLf & "Batch Push Pending Rows" & vbCrLf & "-> Mark is_synced=true", RGB(239, 246, 255), RGB(37, 99, 235), RGB(30, 64, 175), False, 7.5

    ' Convergence to Done State
    AddArrow doc, curRng, 129, baseY + 145, 230, baseY + 225, RGB(5, 150, 105)
    AddArrow doc, curRng, 465, baseY + 205, 364, baseY + 225, RGB(37, 99, 235)

    AddBox doc, curRng, 210, baseY + 225, 174, 25, "State: Operation Complete", RGB(236, 253, 245), RGB(5, 150, 105), RGB(6, 95, 70), True, 8, msoShapeOval

    AddCaption doc, "Figure 7", "State Machine / Activity Diagram of Offline-First SQLite Caching and Supabase Sync."
    Application.ScreenUpdating = True
    MsgBox "Figure 7 Generated Successfully!", vbInformation, "NutriSense"
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

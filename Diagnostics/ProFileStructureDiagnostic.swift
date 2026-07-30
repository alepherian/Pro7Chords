import AppKit
import Foundation
import SwiftProtobuf

struct CueMaster {
    let name: String
    let identifier: String
    let cueIdentifiers: [String]
}

struct TargetTextElement {
    let label: String
    let expectedElementID: String
    let master: CueMaster
    let cue: RVData_Cue
    let actionIndex: Int
    let elementIndex: Int
    let element: RVData_Graphics.Element
    let text: RVData_Graphics.Text
    let rawRTF: String
    let plainText: String
    let chordAttributes: [RVData_Graphics.Text.Attributes.CustomAttribute]
}

@main
struct ProFileStructureDiagnostic {
    private static let workingElementID = "7B12E3CD-5A7E-47E3-AEFA-544881CA4A6F"
    private static let brokenElementID = "F764F03B-55E5-417B-BBE2-3437AE758043"

    static func main() throws {
        let inputPath = CommandLine.arguments.dropFirst().first
            ?? "/Users/adamhill/Desktop/Test Chord Song_chords.pro"
        let inputURL = URL(fileURLWithPath: inputPath)
        let data = try Data(contentsOf: inputURL)
        let presentation = try RVData_Presentation(serializedBytes: data)

        let masters = presentation.cueGroups.enumerated().map { index, cueGroup in
            CueMaster(
                name: displayName(for: cueGroup, fallbackIndex: index),
                identifier: cueGroup.group.uuid.string,
                cueIdentifiers: cueGroup.cueIdentifiers.map(\.string)
            )
        }
        var masterByCueID: [String: CueMaster] = [:]
        for master in masters {
            for cueID in master.cueIdentifiers {
                masterByCueID[cueID] = master
            }
        }

        let targets = findTargets(in: presentation, masterByCueID: masterByCueID)
        guard let working = targets[workingElementID] else {
            throw DiagnosticError.missingTarget("Working element not found: \(workingElementID)")
        }
        guard let broken = targets[brokenElementID] else {
            throw DiagnosticError.missingTarget("Broken element not found: \(brokenElementID)")
        }

        printHeader("File")
        print("Path: \(inputURL.path)")
        print("Presentation: \(presentation.name)")
        print("Presentation ID: \(presentation.uuid.string)")

        printTarget(working)
        printTarget(broken)

        printHeader("Field-by-Field Comparison")
        printComparison(
            title: "Text Container: Working Alpha Element vs Broken Lima Element",
            lhsName: "working.element.text",
            lhsFields: textFieldDump(working.text),
            rhsName: "broken.element.text",
            rhsFields: textFieldDump(broken.text)
        )

        let pairCount = max(working.chordAttributes.count, broken.chordAttributes.count)
        for index in 0..<pairCount {
            let lhsFields = index < working.chordAttributes.count
                ? customAttributeFieldDump(working.chordAttributes[index])
                : [FieldValue(name: "missing", value: "true")]
            let rhsFields = index < broken.chordAttributes.count
                ? customAttributeFieldDump(broken.chordAttributes[index])
                : [FieldValue(name: "missing", value: "true")]

            printComparison(
                title: "Chord Attribute \(index + 1): Working Alpha vs Broken Lima",
                lhsName: "working.chordAttributes[\(index)]",
                lhsFields: lhsFields,
                rhsName: "broken.chordAttributes[\(index)]",
                rhsFields: rhsFields
            )
        }
    }

    private static func findTargets(
        in presentation: RVData_Presentation,
        masterByCueID: [String: CueMaster]
    ) -> [String: TargetTextElement] {
        var targets: [String: TargetTextElement] = [:]

        for cue in presentation.cues {
            guard let master = masterByCueID[cue.uuid.string] else {
                continue
            }

            for (actionIndex, action) in cue.actions.enumerated() {
                guard case .slide(let slideType) = action.actionTypeData,
                      case .presentation(let presentationSlide) = slideType.slide else {
                    continue
                }

                for (elementIndex, slideElement) in presentationSlide.baseSlide.elements.enumerated() {
                    let element = slideElement.element
                    guard element.hasText else {
                        continue
                    }

                    let elementID = element.uuid.string
                    guard elementID == workingElementID || elementID == brokenElementID else {
                        continue
                    }

                    let text = element.text
                    let rawRTF = decodeBytes(text.rtfData)
                    let plainText = plainTextFromRTFData(text.rtfData)
                    let label = elementID == workingElementID ? "Working Line" : "Broken Line"
                    targets[elementID] = TargetTextElement(
                        label: label,
                        expectedElementID: elementID,
                        master: master,
                        cue: cue,
                        actionIndex: actionIndex,
                        elementIndex: elementIndex,
                        element: element,
                        text: text,
                        rawRTF: rawRTF,
                        plainText: plainText,
                        chordAttributes: text.attributes.customAttributes.filter { !$0.chord.isEmpty }
                    )
                }
            }
        }

        return targets
    }

    private static func printTarget(_ target: TargetTextElement) {
        printHeader(target.label)
        print("Master: \(target.master.name)")
        print("Master ID: \(target.master.identifier)")
        print("Cue ID: \(target.cue.uuid.string)")
        print("Cue name: \(emptyFallback(target.cue.name, fallback: "(unnamed cue)"))")
        print("Action index: \(target.actionIndex)")
        print("Element index: \(target.elementIndex)")
        print("Element ID: \(target.element.uuid.string)")
        print("Chord attribute count on text container: \(target.text.attributes.customAttributes.count)")
        print("Chord attribute count after chord filter: \(target.chordAttributes.count)")
        printBlock(title: "Decoded Plain Text", body: target.plainText)
        printBlock(title: "Raw RTF String", body: target.rawRTF)

        print("")
        print("Complete Text Container Field Dump:")
        printFields(textFieldDump(target.text), indent: "  ")

        for (index, attribute) in target.chordAttributes.enumerated() {
            print("")
            print("Complete Chord Attribute \(index + 1) Field Dump:")
            printFields(customAttributeFieldDump(attribute), indent: "  ")
        }
    }

    private static func textFieldDump(_ text: RVData_Graphics.Text) -> [FieldValue] {
        var fields: [FieldValue] = []
        fields.append(.init(name: "attributes.present", value: String(text.hasAttributes)))
        fields.append(contentsOf: attributesFieldDump(text.attributes).prefixed("attributes."))
        fields.append(.init(name: "shadow.present", value: String(text.hasShadow)))
        fields.append(.init(name: "shadow.value.text_format", value: textFormat(text.shadow)))
        fields.append(.init(name: "rtf_data.byte_count", value: String(text.rtfData.count)))
        fields.append(.init(name: "rtf_data.utf8_string", value: decodeBytes(text.rtfData)))
        fields.append(.init(name: "rtf_data.decoded_plain_text", value: plainTextFromRTFData(text.rtfData)))
        fields.append(.init(name: "vertical_alignment.raw_value", value: String(text.verticalAlignment.rawValue)))
        fields.append(.init(name: "vertical_alignment.value", value: "\(text.verticalAlignment)"))
        fields.append(.init(name: "scale_behavior.raw_value", value: String(text.scaleBehavior.rawValue)))
        fields.append(.init(name: "scale_behavior.value", value: "\(text.scaleBehavior)"))
        fields.append(.init(name: "margins.present", value: String(text.hasMargins)))
        fields.append(.init(name: "margins.value.text_format", value: textFormat(text.margins)))
        fields.append(.init(name: "is_superscript_standardized", value: String(text.isSuperscriptStandardized)))
        fields.append(.init(name: "transform.raw_value", value: String(text.transform.rawValue)))
        fields.append(.init(name: "transform.value", value: "\(text.transform)"))
        fields.append(.init(name: "transformDelimiter", value: printableString(text.transformDelimiter)))
        fields.append(.init(name: "chord_pro.present", value: String(text.hasChordPro)))
        fields.append(contentsOf: chordProFieldDump(text.chordPro).prefixed("chord_pro."))
        fields.append(.init(name: "unknown_fields", value: "\(text.unknownFields)"))
        return fields
    }

    private static func attributesFieldDump(_ attributes: RVData_Graphics.Text.Attributes) -> [FieldValue] {
        var fields: [FieldValue] = []
        fields.append(.init(name: "font.present", value: String(attributes.hasFont)))
        fields.append(.init(name: "font.value.text_format", value: textFormat(attributes.font)))
        fields.append(.init(name: "capitalization.raw_value", value: String(attributes.capitalization.rawValue)))
        fields.append(.init(name: "capitalization.value", value: "\(attributes.capitalization)"))
        fields.append(.init(name: "underline_style.present", value: String(attributes.hasUnderlineStyle)))
        fields.append(.init(name: "underline_style.value.text_format", value: textFormat(attributes.underlineStyle)))
        fields.append(.init(name: "underline_color.present", value: String(attributes.hasUnderlineColor)))
        fields.append(.init(name: "underline_color.value.text_format", value: textFormat(attributes.underlineColor)))
        fields.append(.init(name: "paragraph_style.present", value: String(attributes.hasParagraphStyle)))
        fields.append(.init(name: "paragraph_style.value.text_format", value: textFormat(attributes.paragraphStyle)))
        fields.append(.init(name: "kerning", value: String(attributes.kerning)))
        fields.append(.init(name: "superscript", value: String(attributes.superscript)))
        fields.append(.init(name: "strikethrough_style.present", value: String(attributes.hasStrikethroughStyle)))
        fields.append(.init(name: "strikethrough_style.value.text_format", value: textFormat(attributes.strikethroughStyle)))
        fields.append(.init(name: "strikethrough_color.present", value: String(attributes.hasStrikethroughColor)))
        fields.append(.init(name: "strikethrough_color.value.text_format", value: textFormat(attributes.strikethroughColor)))
        fields.append(.init(name: "stroke_width", value: String(attributes.strokeWidth)))
        fields.append(.init(name: "stroke_color.present", value: String(attributes.hasStrokeColor)))
        fields.append(.init(name: "stroke_color.value.text_format", value: textFormat(attributes.strokeColor)))
        fields.append(.init(name: "custom_attributes.count", value: String(attributes.customAttributes.count)))
        for (index, attribute) in attributes.customAttributes.enumerated() {
            fields.append(contentsOf: customAttributeFieldDump(attribute).prefixed("custom_attributes[\(index)]."))
        }
        fields.append(.init(name: "background_color.present", value: String(attributes.hasBackgroundColor)))
        fields.append(.init(name: "background_color.value.text_format", value: textFormat(attributes.backgroundColor)))
        fields.append(.init(name: "fill.oneof_case", value: attributesFillCaseName(attributes.fill)))
        fields.append(.init(name: "fill.text_solid_fill.selected", value: String(isTextSolidFill(attributes.fill))))
        fields.append(.init(name: "fill.text_solid_fill.value.text_format", value: textFormat(attributes.textSolidFill)))
        fields.append(.init(name: "fill.text_gradient_fill.selected", value: String(isTextGradientFill(attributes.fill))))
        fields.append(.init(name: "fill.text_gradient_fill.value.text_format", value: textFormat(attributes.textGradientFill)))
        fields.append(.init(name: "fill.cut_out_fill.selected", value: String(isCutOutFill(attributes.fill))))
        fields.append(.init(name: "fill.cut_out_fill.value.text_format", value: textFormat(attributes.cutOutFill)))
        fields.append(.init(name: "fill.media_fill.selected", value: String(isMediaFill(attributes.fill))))
        fields.append(.init(name: "fill.media_fill.value.text_format", value: textFormat(attributes.mediaFill)))
        fields.append(.init(name: "fill.background_effect.selected", value: String(isBackgroundEffect(attributes.fill))))
        fields.append(.init(name: "fill.background_effect.value.text_format", value: textFormat(attributes.backgroundEffect)))
        fields.append(.init(name: "unknown_fields", value: "\(attributes.unknownFields)"))
        return fields
    }

    private static func chordProFieldDump(_ chordPro: RVData_Graphics.Text.ChordPro) -> [FieldValue] {
        [
            .init(name: "enabled", value: String(chordPro.enabled)),
            .init(name: "notation.raw_value", value: String(chordPro.notation.rawValue)),
            .init(name: "notation.value", value: "\(chordPro.notation)"),
            .init(name: "color.present", value: String(chordPro.hasColor)),
            .init(name: "color.value.text_format", value: textFormat(chordPro.color)),
            .init(name: "unknown_fields", value: "\(chordPro.unknownFields)"),
            .init(name: "serialized_hex", value: serializedHex(chordPro))
        ]
    }

    private static func customAttributeFieldDump(
        _ attribute: RVData_Graphics.Text.Attributes.CustomAttribute
    ) -> [FieldValue] {
        [
            .init(name: "range.present", value: String(attribute.hasRange)),
            .init(name: "range.start", value: String(attribute.range.start)),
            .init(name: "range.end", value: String(attribute.range.end)),
            .init(name: "attribute.oneof_case", value: customAttributeCaseName(attribute.attribute)),
            .init(name: "attribute.capitalization.selected", value: String(isCapitalization(attribute.attribute))),
            .init(name: "attribute.capitalization.raw_value", value: String(attribute.capitalization.rawValue)),
            .init(name: "attribute.capitalization.value", value: "\(attribute.capitalization)"),
            .init(name: "attribute.original_font_size.selected", value: String(isOriginalFontSize(attribute.attribute))),
            .init(name: "attribute.original_font_size.value", value: String(attribute.originalFontSize)),
            .init(name: "attribute.font_scale_factor.selected", value: String(isFontScaleFactor(attribute.attribute))),
            .init(name: "attribute.font_scale_factor.value", value: String(attribute.fontScaleFactor)),
            .init(name: "attribute.text_gradient_fill.selected", value: String(isTextGradientFillAttribute(attribute.attribute))),
            .init(name: "attribute.text_gradient_fill.value.text_format", value: textFormat(attribute.textGradientFill)),
            .init(name: "attribute.should_preserve_foreground_color.selected", value: String(isShouldPreserveForegroundColor(attribute.attribute))),
            .init(name: "attribute.should_preserve_foreground_color.value", value: String(attribute.shouldPreserveForegroundColor)),
            .init(name: "attribute.chord.selected", value: String(isChord(attribute.attribute))),
            .init(name: "attribute.chord.value", value: printableString(attribute.chord)),
            .init(name: "attribute.cut_out_fill.selected", value: String(isCutOutFillAttribute(attribute.attribute))),
            .init(name: "attribute.cut_out_fill.value.text_format", value: textFormat(attribute.cutOutFill)),
            .init(name: "attribute.media_fill.selected", value: String(isMediaFillAttribute(attribute.attribute))),
            .init(name: "attribute.media_fill.value.text_format", value: textFormat(attribute.mediaFill)),
            .init(name: "attribute.background_effect.selected", value: String(isBackgroundEffectAttribute(attribute.attribute))),
            .init(name: "attribute.background_effect.value.text_format", value: textFormat(attribute.backgroundEffect)),
            .init(name: "unknown_fields", value: "\(attribute.unknownFields)"),
            .init(name: "serialized_hex", value: serializedHex(attribute))
        ]
    }

    private static func printComparison(
        title: String,
        lhsName: String,
        lhsFields: [FieldValue],
        rhsName: String,
        rhsFields: [FieldValue]
    ) {
        print("")
        print("-- \(title) --")
        let lhsMap = Dictionary(uniqueKeysWithValues: lhsFields.map { ($0.name, $0.value) })
        let rhsMap = Dictionary(uniqueKeysWithValues: rhsFields.map { ($0.name, $0.value) })
        let names = Array(Set(lhsMap.keys).union(rhsMap.keys)).sorted()
        var differenceCount = 0

        for name in names {
            let lhsValue = lhsMap[name] ?? "(missing field from left dump)"
            let rhsValue = rhsMap[name] ?? "(missing field from right dump)"
            if lhsValue == rhsValue {
                print("SAME \(name): \(lhsValue)")
            } else {
                differenceCount += 1
                print("DIFF \(name)")
                print("  \(lhsName): \(lhsValue)")
                print("  \(rhsName): \(rhsValue)")
            }
        }
        print("Difference count: \(differenceCount)")
    }

    private static func printFields(_ fields: [FieldValue], indent: String) {
        for field in fields {
            print("\(indent)\(field.name): \(field.value)")
        }
    }

    private static func displayName(for cueGroup: RVData_Presentation.CueGroup, fallbackIndex: Int) -> String {
        if !cueGroup.group.name.isEmpty {
            return cueGroup.group.name
        }
        if !cueGroup.group.applicationGroupName.isEmpty {
            return cueGroup.group.applicationGroupName
        }
        return "(unnamed master \(fallbackIndex + 1))"
    }

    private static func decodeBytes(_ data: Data) -> String {
        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8
        }
        if let ascii = String(data: data, encoding: .ascii) {
            return ascii
        }
        return data.map { String(format: "%02x", $0) }.joined(separator: " ")
    }

    private static func plainTextFromRTFData(_ data: Data) -> String {
        guard !data.isEmpty else {
            return ""
        }

        do {
            let attributedString = try NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            )
            return attributedString.string
        } catch {
            return "(RTF decode failed: \(error.localizedDescription))"
        }
    }

    private static func printHeader(_ title: String) {
        print("")
        print("==== \(title) ====")
    }

    private static func printBlock(title: String, body: String) {
        print("\(title):")
        print("----- BEGIN \(title) -----")
        print(body)
        print("----- END \(title) -----")
    }

    private static func textFormat<T: SwiftProtobuf.Message>(_ message: T) -> String {
        let text = message.textFormatString()
        return text.isEmpty ? "(default empty message)" : text
    }

    private static func serializedHex<T: SwiftProtobuf.Message>(_ message: T) -> String {
        do {
            let bytes: [UInt8] = try message.serializedBytes()
            return bytes.map { String(format: "%02x", $0) }.joined(separator: " ")
        } catch {
            return "(serialize failed: \(error.localizedDescription))"
        }
    }

    private static func printableString(_ value: String) -> String {
        value.isEmpty ? "(empty string)" : value
    }

    private static func emptyFallback(_ value: String, fallback: String) -> String {
        value.isEmpty ? fallback : value
    }

    private static func customAttributeCaseName(
        _ attribute: RVData_Graphics.Text.Attributes.CustomAttribute.OneOf_Attribute?
    ) -> String {
        switch attribute {
        case nil:
            return "(unset)"
        case .capitalization:
            return "capitalization"
        case .originalFontSize:
            return "original_font_size"
        case .fontScaleFactor:
            return "font_scale_factor"
        case .textGradientFill:
            return "text_gradient_fill"
        case .shouldPreserveForegroundColor:
            return "should_preserve_foreground_color"
        case .chord:
            return "chord"
        case .cutOutFill:
            return "cut_out_fill"
        case .mediaFill:
            return "media_fill"
        case .backgroundEffect:
            return "background_effect"
        }
    }

    private static func attributesFillCaseName(_ fill: RVData_Graphics.Text.Attributes.OneOf_Fill?) -> String {
        switch fill {
        case nil:
            return "(unset)"
        case .textSolidFill:
            return "text_solid_fill"
        case .textGradientFill:
            return "text_gradient_fill"
        case .cutOutFill:
            return "cut_out_fill"
        case .mediaFill:
            return "media_fill"
        case .backgroundEffect:
            return "background_effect"
        }
    }

    private static func isCapitalization(_ attribute: RVData_Graphics.Text.Attributes.CustomAttribute.OneOf_Attribute?) -> Bool {
        if case .capitalization = attribute { return true }
        return false
    }

    private static func isOriginalFontSize(_ attribute: RVData_Graphics.Text.Attributes.CustomAttribute.OneOf_Attribute?) -> Bool {
        if case .originalFontSize = attribute { return true }
        return false
    }

    private static func isFontScaleFactor(_ attribute: RVData_Graphics.Text.Attributes.CustomAttribute.OneOf_Attribute?) -> Bool {
        if case .fontScaleFactor = attribute { return true }
        return false
    }

    private static func isTextGradientFillAttribute(_ attribute: RVData_Graphics.Text.Attributes.CustomAttribute.OneOf_Attribute?) -> Bool {
        if case .textGradientFill = attribute { return true }
        return false
    }

    private static func isShouldPreserveForegroundColor(_ attribute: RVData_Graphics.Text.Attributes.CustomAttribute.OneOf_Attribute?) -> Bool {
        if case .shouldPreserveForegroundColor = attribute { return true }
        return false
    }

    private static func isChord(_ attribute: RVData_Graphics.Text.Attributes.CustomAttribute.OneOf_Attribute?) -> Bool {
        if case .chord = attribute { return true }
        return false
    }

    private static func isCutOutFillAttribute(_ attribute: RVData_Graphics.Text.Attributes.CustomAttribute.OneOf_Attribute?) -> Bool {
        if case .cutOutFill = attribute { return true }
        return false
    }

    private static func isMediaFillAttribute(_ attribute: RVData_Graphics.Text.Attributes.CustomAttribute.OneOf_Attribute?) -> Bool {
        if case .mediaFill = attribute { return true }
        return false
    }

    private static func isBackgroundEffectAttribute(_ attribute: RVData_Graphics.Text.Attributes.CustomAttribute.OneOf_Attribute?) -> Bool {
        if case .backgroundEffect = attribute { return true }
        return false
    }

    private static func isTextSolidFill(_ fill: RVData_Graphics.Text.Attributes.OneOf_Fill?) -> Bool {
        if case .textSolidFill = fill { return true }
        return false
    }

    private static func isTextGradientFill(_ fill: RVData_Graphics.Text.Attributes.OneOf_Fill?) -> Bool {
        if case .textGradientFill = fill { return true }
        return false
    }

    private static func isCutOutFill(_ fill: RVData_Graphics.Text.Attributes.OneOf_Fill?) -> Bool {
        if case .cutOutFill = fill { return true }
        return false
    }

    private static func isMediaFill(_ fill: RVData_Graphics.Text.Attributes.OneOf_Fill?) -> Bool {
        if case .mediaFill = fill { return true }
        return false
    }

    private static func isBackgroundEffect(_ fill: RVData_Graphics.Text.Attributes.OneOf_Fill?) -> Bool {
        if case .backgroundEffect = fill { return true }
        return false
    }
}

struct FieldValue {
    let name: String
    let value: String
}

extension Array where Element == FieldValue {
    func prefixed(_ prefix: String) -> [FieldValue] {
        map { FieldValue(name: prefix + $0.name, value: $0.value) }
    }
}

enum DiagnosticError: Error, LocalizedError {
    case missingTarget(String)

    var errorDescription: String? {
        switch self {
        case .missingTarget(let message):
            return message
        }
    }
}

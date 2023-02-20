//
//  main.swift
//  AldermoreConverter
//
//  Created by Daniel Leivers on 16/02/2023.
//

import Foundation
import CommandLineKit
import SwiftCSV

func convertDate(dateString: String) -> String? {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "dd MMM yyyy"
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")

    let relativeFormatter = RelativeDateTimeFormatter()
    relativeFormatter.unitsStyle = .full
    relativeFormatter.locale = Locale(identifier: "en_US_POSIX")

    let relativeDateFormatter = DateFormatter()
    relativeDateFormatter.timeStyle = .none
    relativeDateFormatter.dateStyle = .medium
    relativeDateFormatter.locale = Locale(identifier: "en_GB")
    relativeDateFormatter.doesRelativeDateFormatting = true

    let outputFormatter = DateFormatter()
    outputFormatter.dateFormat = "dd/MM/yyyy"
    outputFormatter.locale = Locale(identifier: "en_US_POSIX")

    if let date = dateFormatter.date(from: dateString) {
        return outputFormatter.string(from: date)
    }
    else if dateString.lowercased() == "yesterday"  {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        return outputFormatter.string(from: yesterday)
    }
    else {
        return nil
    }
}

func convertCurrency(currencyString: String) -> String? {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    guard let currencyNumber = formatter.number(from: currencyString) else { return nil }
    return String(format: "%.02f", currencyNumber.doubleValue)
}
enum Format: String {
    case freeagent = "freeagent"
    case quickbooks = "quickbooks"
}

let cli = CommandLineKit.CommandLine()

let csvFilePath = StringOption(shortFlag: "f", longFlag: "file", required: true,
  helpMessage: "Path to the input CSV file.")
let outputFormat = EnumOption<Format>(longFlag: "format", helpMessage: "Output format, freeagent or quickbooks")
let outputFilePath = StringOption(shortFlag: "o", longFlag: "output",
  helpMessage: "Path to the output CSV file.")

cli.addOptions(csvFilePath, outputFormat, outputFilePath)

do {
    try cli.parse()
} catch {
    cli.printUsage(error)
    exit(EX_USAGE)
}

guard let filePathString = csvFilePath.value, let format = outputFormat.value else {
    print("File \(csvFilePath.value!) doesn't exist")
    exit(EX_USAGE)
}

do {
    let inputUrl = URL(fileURLWithPath: filePathString)
    let csvFile: CSV = try CSV<Named>(url: inputUrl)

    var outputString = String()

    for row in csvFile.rows {
        guard let dateString = row["Date"],
              let outputDate = convertDate(dateString: dateString),
              let amountString = row["Amount"],
              let amount = convertCurrency(currencyString: amountString),
              let description = row["Description"]
        else { continue }

        switch format {
        case .freeagent:
            outputString = outputString.appending("\(outputDate),\(amount),\(description)\n")
        case .quickbooks:
            outputString = outputString.appending("\(outputDate),\(description),\(amount)\n")
        }

    }


    if let outputPathString = outputFilePath.value {
        try outputString.write(toFile: outputPathString, atomically: true, encoding: .utf8)
    }
    else {
        let outputPath = inputUrl.deletingPathExtension().path() + "_converted.csv"
        try outputString.write(toFile: outputPath, atomically: true, encoding: .utf8)
    }
}
catch let parseError as CSVParseError {
    // Catch errors from parsing invalid CSV
    print("CSV syntax is invalid: \(parseError)")
    exit(EX_USAGE)
}
catch {
    // Catch errors from trying to load files
    print("Failed to load file: \(error)")
    exit(EX_USAGE)
}

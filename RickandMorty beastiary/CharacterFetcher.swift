import Foundation
 
 struct CharacterFetcher {
 private let session: URLSession
 
 init(session: URLSession = .shared) {
 self.session = session
 }
 
 func search(name: String) async throws -> [RickMortyCharacter] {
 var components = URLComponents()
 components.scheme = "https"
 components.host = "rickandmortyapi.com"
 components.path = "/api/character/"
 components.queryItems = [
 URLQueryItem(name: "name", value: name)
 ]
 
 guard let url = components.url else {
 throw CharacterFetcherError.invalidURL
 }
 
 let request = URLRequest(url: url, timeoutInterval: 15)
 let (data, response) = try await session.data(for: request)
 
 try Task.checkCancellation()
 
 guard let response = response as? HTTPURLResponse else {
 throw CharacterFetcherError.invalidResponse
     
 }
     if response.statusCode == 429 {
         let retryAfter = response.value(forHTTPHeaderField: "Retry-After")
         print("Too many Ricks retrying", retryAfter ?? "not supplied")
     }
     
     
 if response.statusCode == 404 {
 return []
 }
 
 guard (200...299).contains(response.statusCode) else {
 throw CharacterFetcherError.httpStatus(response.statusCode)
 }
 
 return try Self.decodeCharacters(from: data)
 }
 
 static func decodeCharacters(
 from data: Data
 ) throws -> [RickMortyCharacter] {
 let decoder = JSONDecoder()
 
 decoder.dateDecodingStrategy = .custom { decoder in
 let container = try decoder.singleValueContainer()
 let value = try container.decode(String.self)
 
 let formatter = ISO8601DateFormatter()
 formatter.formatOptions = [
 .withInternetDateTime,
 .withFractionalSeconds
 ]
 
 guard let date = formatter.date(from: value) else {
 throw DecodingError.dataCorruptedError(
 in: container,
 debugDescription: "Invalid character creation date."
 )
 }
 
 return date
 }
 
 return try decoder.decode(
 CharacterResponse.self,
 from: data
 ).results
 }
 }
 
 enum CharacterFetcherError: LocalizedError {
 case invalidURL
 case invalidResponse
 case httpStatus(Int)
 
 var errorDescription: String? {
 switch self {
 case .invalidURL:
 return "The search URL could not be created."
 case .invalidResponse:
 return "The server returned an invalid response."
 case .httpStatus(let code):
     if code == 429 { return "Too many Ricks. Give me a second to adjust the finite curve."}
     return "Search failed to find"
 
 }
 }
 }

import Foundation
import SwiftData

// MARK: - Bundled Library Scanner
// Auto-discovers .epub files bundled in the app's Resources/ directory.
// Creates lightweight Book records for each one, with filename-derived metadata.
// Runs after SeedCatalog so enriched books keep their curated data.

struct BundledLibraryScanner {
    
    // MARK: - Filename → Metadata Mapping
    // Core catalog entries with known author, Gutenberg ID, and category.
    
    struct BookMeta {
        let author: String
        let gutenbergId: String
        let category: String  // Used for path matching
    }
    
    /// Scan the app bundle for .epub files and create Book records for any not yet in the database.
    @MainActor
    static func scanAndSeed(modelContext: ModelContext) {
        // Fetch existing books to avoid duplicates
        let descriptor = FetchDescriptor<Book>()
        guard let existingBooks = try? modelContext.fetch(descriptor) else { return }
        
        let existingFilenames = Set(existingBooks.compactMap { book -> String? in
            guard let uri = book.localFileURI else { return nil }
            return URL(fileURLWithPath: uri).lastPathComponent
        })
        let existingTitles = Set(existingBooks.map { $0.title.lowercased() })
        
        // Find all .epub files in the bundle
        let epubURLs = findAllBundledEPUBs()
        guard !epubURLs.isEmpty else {
            print("📚 Scanner: No bundled EPUBs found")
            return
        }
        
        print("📚 Scanner: Found \(epubURLs.count) bundled EPUBs")
        
        var created = 0
        for url in epubURLs {
            let filename = url.lastPathComponent
            
            // Skip if already imported
            if existingFilenames.contains(filename) { continue }
            
            // Derive title from filename
            let title = titleFromFilename(filename)
            
            // Skip if a book with this title already exists
            if existingTitles.contains(title.lowercased()) { continue }
            
            // Look up metadata
            let meta = CATALOG[filename]
            let author = meta?.author ?? authorFromFilename(filename)
            
            let book = Book(
                title: title,
                author: author,
                bookDescription: "",
                sourceType: .gutenberg,
                language: "en",
                gutenbergId: meta?.gutenbergId
            )
            book.localFileURI = url.path
            book.importStatus = .pending
            
            modelContext.insert(book)
            created += 1
        }
        
        if created > 0 {
            try? modelContext.save()
            print("📚 Scanner: Created \(created) new Book records from bundled EPUBs")
        } else {
            print("📚 Scanner: All bundled EPUBs already in database")
        }
    }
    
    // MARK: - File Discovery
    
    private static func findAllBundledEPUBs() -> [URL] {
        var results: [URL] = []
        
        // Strategy 1: Direct bundle resource search
        if let urls = Bundle.main.urls(forResourcesWithExtension: "epub", subdirectory: nil) {
            results.append(contentsOf: urls)
        }
        
        // Strategy 2: Resources subdirectory
        if let urls = Bundle.main.urls(forResourcesWithExtension: "epub", subdirectory: "Resources") {
            results.append(contentsOf: urls)
        }
        
        // Strategy 3: Recursive scan of bundle
        if let bundlePath = Bundle.main.resourcePath {
            let fm = FileManager.default
            if let enumerator = fm.enumerator(atPath: bundlePath) {
                while let path = enumerator.nextObject() as? String {
                    if path.hasSuffix(".epub") {
                        let fullURL = URL(fileURLWithPath: bundlePath).appendingPathComponent(path)
                        if !results.contains(fullURL) {
                            results.append(fullURL)
                        }
                    }
                }
            }
        }
        
        // Deduplicate by filename
        var seen = Set<String>()
        return results.filter { url in
            let fn = url.lastPathComponent
            if seen.contains(fn) { return false }
            seen.insert(fn)
            return true
        }
    }
    
    // MARK: - Title Extraction
    
    /// Convert "TheIliad.epub" → "The Iliad"
    static func titleFromFilename(_ filename: String) -> String {
        var name = (filename as NSString).deletingPathExtension
        
        // Handle special suffixes like _Part1, Vol1
        name = name.replacingOccurrences(of: "_Part", with: " Part ")
            .replacingOccurrences(of: "_Vol", with: " Vol ")
            .replacingOccurrences(of: "_", with: " ")
        
        // Insert spaces before uppercase letters (CamelCase → spaced)
        var result = ""
        for (i, char) in name.enumerated() {
            if i > 0 && char.isUppercase {
                let prev = name[name.index(name.startIndex, offsetBy: i - 1)]
                if prev.isLowercase || prev.isNumber {
                    result.append(" ")
                }
            }
            result.append(char)
        }
        
        return result.trimmingCharacters(in: .whitespaces)
    }
    
    /// Best-effort author from filename pattern
    private static func authorFromFilename(_ filename: String) -> String {
        if let meta = CATALOG[filename] {
            return meta.author
        }
        return "Unknown"
    }
    
    // MARK: - Core Catalog
    // Maps filename → (author, gutenbergId, category)
    // Categories: "greek", "philosophy", "shakespeare", "science", "history",
    //             "fiction", "poetry", "drama", "theology", "mathematics"
    
    static let CATALOG: [String: BookMeta] = [
        // Homer
        "TheIliad.epub": BookMeta(author: "Homer", gutenbergId: "2199", category: "greek"),
        "TheOdyssey.epub": BookMeta(author: "Homer", gutenbergId: "1727", category: "greek"),
        
        // Aeschylus
        "PrometheusBound.epub": BookMeta(author: "Aeschylus", gutenbergId: "8714", category: "drama"),
        "ThePersians.epub": BookMeta(author: "Aeschylus", gutenbergId: "8677", category: "drama"),
        "SevenAgainstThebes.epub": BookMeta(author: "Aeschylus", gutenbergId: "8678", category: "drama"),
        "TheSuppliantMaidens.epub": BookMeta(author: "Aeschylus", gutenbergId: "8676", category: "drama"),
        "Agamemnon.epub": BookMeta(author: "Aeschylus", gutenbergId: "14417", category: "drama"),
        
        // Sophocles
        "OedipusTheKing.epub": BookMeta(author: "Sophocles", gutenbergId: "31", category: "drama"),
        "OedipusAtColonus.epub": BookMeta(author: "Sophocles", gutenbergId: "7927", category: "drama"),
        "Antigone.epub": BookMeta(author: "Sophocles", gutenbergId: "16377", category: "drama"),
        "Ajax.epub": BookMeta(author: "Sophocles", gutenbergId: "8788", category: "drama"),
        "ElectraSophocles.epub": BookMeta(author: "Sophocles", gutenbergId: "14484", category: "drama"),
        "TheTrachiniae.epub": BookMeta(author: "Sophocles", gutenbergId: "7840", category: "drama"),
        "Philoctetes.epub": BookMeta(author: "Sophocles", gutenbergId: "8502", category: "drama"),
        
        // Euripides
        "Medea.epub": BookMeta(author: "Euripides", gutenbergId: "35451", category: "drama"),
        "Hippolytus.epub": BookMeta(author: "Euripides", gutenbergId: "14990", category: "drama"),
        "Alcestis.epub": BookMeta(author: "Euripides", gutenbergId: "10523", category: "drama"),
        "Heracleidae.epub": BookMeta(author: "Euripides", gutenbergId: "8513", category: "drama"),
        "TheSuppliants.epub": BookMeta(author: "Euripides", gutenbergId: "8515", category: "drama"),
        "TheTrojanWomen.epub": BookMeta(author: "Euripides", gutenbergId: "8580", category: "drama"),
        "IonEuripides.epub": BookMeta(author: "Euripides", gutenbergId: "8512", category: "drama"),
        "Helen.epub": BookMeta(author: "Euripides", gutenbergId: "8511", category: "drama"),
        "Andromache.epub": BookMeta(author: "Euripides", gutenbergId: "8514", category: "drama"),
        "ElectraEuripides.epub": BookMeta(author: "Euripides", gutenbergId: "8509", category: "drama"),
        "Bacchantes.epub": BookMeta(author: "Euripides", gutenbergId: "8508", category: "drama"),
        "Hecuba.epub": BookMeta(author: "Euripides", gutenbergId: "8510", category: "drama"),
        "HeraclesMad.epub": BookMeta(author: "Euripides", gutenbergId: "8507", category: "drama"),
        "ThePhoenicianWomen.epub": BookMeta(author: "Euripides", gutenbergId: "8506", category: "drama"),
        "Orestes.epub": BookMeta(author: "Euripides", gutenbergId: "8505", category: "drama"),
        "IphigeniaInTauris.epub": BookMeta(author: "Euripides", gutenbergId: "8503", category: "drama"),
        "IphigeniaInAulis.epub": BookMeta(author: "Euripides", gutenbergId: "8504", category: "drama"),
        "Cyclops.epub": BookMeta(author: "Euripides", gutenbergId: "8501", category: "drama"),
        "Rhesus.epub": BookMeta(author: "Euripides", gutenbergId: "8516", category: "drama"),
        
        // Aristophanes
        "TheAcharnians.epub": BookMeta(author: "Aristophanes", gutenbergId: "3012", category: "drama"),
        "TheKnights.epub": BookMeta(author: "Aristophanes", gutenbergId: "3011", category: "drama"),
        "TheClouds.epub": BookMeta(author: "Aristophanes", gutenbergId: "3160", category: "drama"),
        "Peace.epub": BookMeta(author: "Aristophanes", gutenbergId: "3013", category: "drama"),
        "TheBirds.epub": BookMeta(author: "Aristophanes", gutenbergId: "3014", category: "drama"),
        "TheFrogs.epub": BookMeta(author: "Aristophanes", gutenbergId: "3015", category: "drama"),
        "Lysistrata.epub": BookMeta(author: "Aristophanes", gutenbergId: "7700", category: "drama"),
        "Thesmophoriazusae.epub": BookMeta(author: "Aristophanes", gutenbergId: "3421", category: "drama"),
        "Ecclesiazousae.epub": BookMeta(author: "Aristophanes", gutenbergId: "3244", category: "drama"),
        "Plutus.epub": BookMeta(author: "Aristophanes", gutenbergId: "3679", category: "drama"),
        
        // History
        "TheHistoryOfHerodotus.epub": BookMeta(author: "Herodotus", gutenbergId: "2707", category: "history"),
        "HistoryOfThePeloponnesianWar.epub": BookMeta(author: "Thucydides", gutenbergId: "7142", category: "history"),
        "PlutarchsLives.epub": BookMeta(author: "Plutarch", gutenbergId: "674", category: "history"),
        "TheAnnalsTacitus.epub": BookMeta(author: "Tacitus", gutenbergId: "3296", category: "history"),
        "TheHistoriesTacitus.epub": BookMeta(author: "Tacitus", gutenbergId: "16927", category: "history"),
        "TheDeclineAndFallOfTheRomanEmpire.epub": BookMeta(author: "Edward Gibbon", gutenbergId: "25717", category: "history"),
        "ThePhilosophyOfHistory.epub": BookMeta(author: "G.W.F. Hegel", gutenbergId: "51635", category: "history"),
        
        // Plato
        "Charmides.epub": BookMeta(author: "Plato", gutenbergId: "1580", category: "philosophy"),
        "Lysis.epub": BookMeta(author: "Plato", gutenbergId: "1579", category: "philosophy"),
        "Laches.epub": BookMeta(author: "Plato", gutenbergId: "1584", category: "philosophy"),
        "Protagoras.epub": BookMeta(author: "Plato", gutenbergId: "1591", category: "philosophy"),
        "Euthydemus.epub": BookMeta(author: "Plato", gutenbergId: "1598", category: "philosophy"),
        "Cratylus.epub": BookMeta(author: "Plato", gutenbergId: "1616", category: "philosophy"),
        "Phaedrus.epub": BookMeta(author: "Plato", gutenbergId: "1636", category: "philosophy"),
        "IonPlato.epub": BookMeta(author: "Plato", gutenbergId: "1635", category: "philosophy"),
        "Symposium.epub": BookMeta(author: "Plato", gutenbergId: "1600", category: "philosophy"),
        "Meno.epub": BookMeta(author: "Plato", gutenbergId: "1643", category: "philosophy"),
        "Euthyphro.epub": BookMeta(author: "Plato", gutenbergId: "1642", category: "philosophy"),
        "Apology.epub": BookMeta(author: "Plato", gutenbergId: "1656", category: "philosophy"),
        "Crito.epub": BookMeta(author: "Plato", gutenbergId: "1657", category: "philosophy"),
        "Phaedo.epub": BookMeta(author: "Plato", gutenbergId: "1658", category: "philosophy"),
        "Gorgias.epub": BookMeta(author: "Plato", gutenbergId: "1672", category: "philosophy"),
        "TheRepublic.epub": BookMeta(author: "Plato", gutenbergId: "1497", category: "philosophy"),
        "Timaeus.epub": BookMeta(author: "Plato", gutenbergId: "1572", category: "philosophy"),
        "Critias.epub": BookMeta(author: "Plato", gutenbergId: "1571", category: "philosophy"),
        "Parmenides.epub": BookMeta(author: "Plato", gutenbergId: "1687", category: "philosophy"),
        "Theaetetus.epub": BookMeta(author: "Plato", gutenbergId: "1700", category: "philosophy"),
        "Sophist.epub": BookMeta(author: "Plato", gutenbergId: "1735", category: "philosophy"),
        "Statesman.epub": BookMeta(author: "Plato", gutenbergId: "1738", category: "philosophy"),
        "Philebus.epub": BookMeta(author: "Plato", gutenbergId: "1744", category: "philosophy"),
        "Laws.epub": BookMeta(author: "Plato", gutenbergId: "1750", category: "philosophy"),
        
        // Aristotle
        "Categories.epub": BookMeta(author: "Aristotle", gutenbergId: "6762", category: "philosophy"),
        "OnInterpretation.epub": BookMeta(author: "Aristotle", gutenbergId: "6763", category: "philosophy"),
        "PriorAnalytics.epub": BookMeta(author: "Aristotle", gutenbergId: "6764", category: "philosophy"),
        "PosteriorAnalytics.epub": BookMeta(author: "Aristotle", gutenbergId: "6765", category: "philosophy"),
        "Topics.epub": BookMeta(author: "Aristotle", gutenbergId: "6766", category: "philosophy"),
        "SophisticalRefutations.epub": BookMeta(author: "Aristotle", gutenbergId: "6767", category: "philosophy"),
        "Physics.epub": BookMeta(author: "Aristotle", gutenbergId: "6747", category: "philosophy"),
        "OnTheHeavens.epub": BookMeta(author: "Aristotle", gutenbergId: "6748", category: "philosophy"),
        "OnGenerationAndCorruption.epub": BookMeta(author: "Aristotle", gutenbergId: "6750", category: "philosophy"),
        "Meteorology.epub": BookMeta(author: "Aristotle", gutenbergId: "6757", category: "philosophy"),
        "Metaphysics.epub": BookMeta(author: "Aristotle", gutenbergId: "8438", category: "philosophy"),
        "OnTheSoul.epub": BookMeta(author: "Aristotle", gutenbergId: "6753", category: "philosophy"),
        "NicomacheanEthics.epub": BookMeta(author: "Aristotle", gutenbergId: "6867", category: "philosophy"),
        "Politics.epub": BookMeta(author: "Aristotle", gutenbergId: "6868", category: "philosophy"),
        "Rhetoric.epub": BookMeta(author: "Aristotle", gutenbergId: "6870", category: "philosophy"),
        "Poetics.epub": BookMeta(author: "Aristotle", gutenbergId: "1974", category: "philosophy"),
        "TheAthenianConstitution.epub": BookMeta(author: "Aristotle", gutenbergId: "2680", category: "philosophy"),
        "OnSenseAndTheSensible.epub": BookMeta(author: "Aristotle", gutenbergId: "6752", category: "philosophy"),
        "OnMemoryAndReminiscence.epub": BookMeta(author: "Aristotle", gutenbergId: "6755", category: "philosophy"),
        "OnSleepAndSleeplessness.epub": BookMeta(author: "Aristotle", gutenbergId: "6754", category: "philosophy"),
        "OnDreams.epub": BookMeta(author: "Aristotle", gutenbergId: "6756", category: "philosophy"),
        "OnProphesyingByDreams.epub": BookMeta(author: "Aristotle", gutenbergId: "6758", category: "philosophy"),
        "OnLongevityAndShortnessOfLife.epub": BookMeta(author: "Aristotle", gutenbergId: "6759", category: "philosophy"),
        "OnYouthAndOldAge.epub": BookMeta(author: "Aristotle", gutenbergId: "6760", category: "philosophy"),
        "HistoryOfAnimals.epub": BookMeta(author: "Aristotle", gutenbergId: "6745", category: "science"),
        "PartsOfAnimals.epub": BookMeta(author: "Aristotle", gutenbergId: "6742", category: "science"),
        "OnTheMotionOfAnimals.epub": BookMeta(author: "Aristotle", gutenbergId: "6741", category: "science"),
        "OnTheGaitOfAnimals.epub": BookMeta(author: "Aristotle", gutenbergId: "6740", category: "science"),
        "OnTheGenerationOfAnimals.epub": BookMeta(author: "Aristotle", gutenbergId: "6743", category: "science"),
        
        // Mathematics & Science
        "ElementsOfEuclid.epub": BookMeta(author: "Euclid", gutenbergId: "21076", category: "mathematics"),
        "WorksOfArchimedes.epub": BookMeta(author: "Archimedes", gutenbergId: "7148", category: "mathematics"),
        "WorksOfHippocrates.epub": BookMeta(author: "Hippocrates", gutenbergId: "18121", category: "science"),
        "OnTheNaturalFaculties.epub": BookMeta(author: "Galen", gutenbergId: "43383", category: "science"),
        "TheOriginOfSpecies.epub": BookMeta(author: "Charles Darwin", gutenbergId: "1228", category: "science"),
        "TheDescentOfMan.epub": BookMeta(author: "Charles Darwin", gutenbergId: "2300", category: "science"),
        "Opticks.epub": BookMeta(author: "Isaac Newton", gutenbergId: "33504", category: "science"),
        "TreatiseOnLight.epub": BookMeta(author: "Christiaan Huygens", gutenbergId: "14725", category: "science"),
        "OnTheLoadstone.epub": BookMeta(author: "William Gilbert", gutenbergId: "33228", category: "science"),
        "DialoguesConcerningTwoNewSciences.epub": BookMeta(author: "Galileo Galilei", gutenbergId: "37729", category: "science"),
        "OnTheMotionOfTheHeartAndBlood.epub": BookMeta(author: "William Harvey", gutenbergId: "28233", category: "science"),
        "ElementsOfChemistry.epub": BookMeta(author: "Antoine Lavoisier", gutenbergId: "30775", category: "science"),
        "ExperimentalResearchesInElectricity.epub": BookMeta(author: "Michael Faraday", gutenbergId: "14078", category: "science"),
        
        // Roman Philosophy & Poetry
        "OnTheNatureOfThings.epub": BookMeta(author: "Lucretius", gutenbergId: "785", category: "philosophy"),
        "TheDiscoursesOfEpictetus.epub": BookMeta(author: "Epictetus", gutenbergId: "10661", category: "philosophy"),
        "TheMeditations.epub": BookMeta(author: "Marcus Aurelius", gutenbergId: "15877", category: "philosophy"),
        "TheAeneid.epub": BookMeta(author: "Virgil", gutenbergId: "227", category: "poetry"),
        "Eclogues.epub": BookMeta(author: "Virgil", gutenbergId: "230", category: "poetry"),
        "Georgics.epub": BookMeta(author: "Virgil", gutenbergId: "232", category: "poetry"),
        "TheSixEnneads.epub": BookMeta(author: "Plotinus", gutenbergId: "49447", category: "philosophy"),
        
        // Theology
        "TheConfessions.epub": BookMeta(author: "Augustine", gutenbergId: "3296", category: "theology"),
        "TheCityOfGodVol1.epub": BookMeta(author: "Augustine", gutenbergId: "45304", category: "theology"),
        "TheCityOfGodVol2.epub": BookMeta(author: "Augustine", gutenbergId: "45305", category: "theology"),
        "OnChristianDoctrine.epub": BookMeta(author: "Augustine", gutenbergId: "9256", category: "theology"),
        "SummaTheologicaPart1.epub": BookMeta(author: "Thomas Aquinas", gutenbergId: "17611", category: "theology"),
        "SummaTheologicaPart2a.epub": BookMeta(author: "Thomas Aquinas", gutenbergId: "17897", category: "theology"),
        "SummaTheologicaPart2b.epub": BookMeta(author: "Thomas Aquinas", gutenbergId: "18755", category: "theology"),
        "SummaTheologicaPart3.epub": BookMeta(author: "Thomas Aquinas", gutenbergId: "19950", category: "theology"),
        "SummaTheologicaSupplement.epub": BookMeta(author: "Thomas Aquinas", gutenbergId: "19773", category: "theology"),
        
        // Medieval & Renaissance
        "DivineComedy.epub": BookMeta(author: "Dante Alighieri", gutenbergId: "8800", category: "poetry"),
        "TheCanterburyTales.epub": BookMeta(author: "Geoffrey Chaucer", gutenbergId: "2383", category: "poetry"),
        "TroilusAndCriseyde.epub": BookMeta(author: "Geoffrey Chaucer", gutenbergId: "257", category: "poetry"),
        "ThePrince.epub": BookMeta(author: "Niccolò Machiavelli", gutenbergId: "1232", category: "philosophy"),
        "EssaysOfMontaigne.epub": BookMeta(author: "Michel de Montaigne", gutenbergId: "3600", category: "philosophy"),
        
        // Early Modern Philosophy
        "Leviathan.epub": BookMeta(author: "Thomas Hobbes", gutenbergId: "3207", category: "philosophy"),
        "DiscourseOnTheMethod.epub": BookMeta(author: "René Descartes", gutenbergId: "4391", category: "philosophy"),
        "MeditationsOnFirstPhilosophy.epub": BookMeta(author: "René Descartes", gutenbergId: "59", category: "philosophy"),
        "Ethics.epub": BookMeta(author: "Baruch Spinoza", gutenbergId: "3800", category: "philosophy"),
        "ALetterConcerningToleration.epub": BookMeta(author: "John Locke", gutenbergId: "7370", category: "philosophy"),
        "AnEssayConcerningHumanUnderstanding.epub": BookMeta(author: "John Locke", gutenbergId: "10615", category: "philosophy"),
        "ThePrinciplesOfHumanKnowledge.epub": BookMeta(author: "George Berkeley", gutenbergId: "4723", category: "philosophy"),
        "AnEnquiryConcerningHumanUnderstanding.epub": BookMeta(author: "David Hume", gutenbergId: "9662", category: "philosophy"),
        "CritiqueOfPureReason.epub": BookMeta(author: "Immanuel Kant", gutenbergId: "4280", category: "philosophy"),
        "FundamentalPrinciplesOfTheMetaphysicOfMorals.epub": BookMeta(author: "Immanuel Kant", gutenbergId: "5682", category: "philosophy"),
        "CritiqueOfPracticalReason.epub": BookMeta(author: "Immanuel Kant", gutenbergId: "5683", category: "philosophy"),
        "TheCritiqueOfJudgement.epub": BookMeta(author: "Immanuel Kant", gutenbergId: "48433", category: "philosophy"),
        "TheSpiritOfTheLaws.epub": BookMeta(author: "Montesquieu", gutenbergId: "27573", category: "philosophy"),
        "ADiscourseOnInequality.epub": BookMeta(author: "Jean-Jacques Rousseau", gutenbergId: "11136", category: "philosophy"),
        "TheSocialContract.epub": BookMeta(author: "Jean-Jacques Rousseau", gutenbergId: "46333", category: "philosophy"),
        
        // Milton & Pascal
        "ParadiseLost.epub": BookMeta(author: "John Milton", gutenbergId: "20", category: "poetry"),
        "Areopagitica.epub": BookMeta(author: "John Milton", gutenbergId: "608", category: "philosophy"),
        "SamsonAgonistes.epub": BookMeta(author: "John Milton", gutenbergId: "1338", category: "poetry"),
        "TheProvincialLetters.epub": BookMeta(author: "Blaise Pascal", gutenbergId: "73959", category: "theology"),
        "Pensees.epub": BookMeta(author: "Blaise Pascal", gutenbergId: "18269", category: "philosophy"),
        
        // Shakespeare
        "HenryVI_Part1.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1500", category: "shakespeare"),
        "HenryVI_Part2.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1501", category: "shakespeare"),
        "HenryVI_Part3.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1502", category: "shakespeare"),
        "RichardIII.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1503", category: "shakespeare"),
        "TheComedyOfErrors.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1504", category: "shakespeare"),
        "TitusAndronicus.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1505", category: "shakespeare"),
        "TheTamingOfTheShrew.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1508", category: "shakespeare"),
        "TheTwoGentlemenOfVerona.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1509", category: "shakespeare"),
        "LovesLaboursLost.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1510", category: "shakespeare"),
        "RomeoAndJuliet.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1112", category: "shakespeare"),
        "RichardII.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1512", category: "shakespeare"),
        "AMidsummerNightsDream.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1514", category: "shakespeare"),
        "TheLifeAndDeathOfKingJohn.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1511", category: "shakespeare"),
        "TheMerchantOfVenice.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1515", category: "shakespeare"),
        "HenryIV_Part1.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1516", category: "shakespeare"),
        "HenryIV_Part2.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1517", category: "shakespeare"),
        "MuchAdoAboutNothing.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1519", category: "shakespeare"),
        "HenryV.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1521", category: "shakespeare"),
        "JuliusCaesar.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1522", category: "shakespeare"),
        "AsYouLikeIt.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1523", category: "shakespeare"),
        "TwelfthNight.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1526", category: "shakespeare"),
        "Hamlet.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1524", category: "shakespeare"),
        "TheMerryWivesOfWindsor.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1525", category: "shakespeare"),
        "TroilusAndCressida.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1528", category: "shakespeare"),
        "AllsWellThatEndsWell.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1529", category: "shakespeare"),
        "MeasureForMeasure.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1530", category: "shakespeare"),
        "Othello.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1531", category: "shakespeare"),
        "KingLear.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1532", category: "shakespeare"),
        "Macbeth.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1533", category: "shakespeare"),
        "AntonyAndCleopatra.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1534", category: "shakespeare"),
        "Coriolanus.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1535", category: "shakespeare"),
        "TimonOfAthens.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1536", category: "shakespeare"),
        "Pericles.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1537", category: "shakespeare"),
        "Cymbeline.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1538", category: "shakespeare"),
        "TheWintersTale.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1539", category: "shakespeare"),
        "TheTempest.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1540", category: "shakespeare"),
        "HenryVIII.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1541", category: "shakespeare"),
        "Sonnets.epub": BookMeta(author: "William Shakespeare", gutenbergId: "1041", category: "shakespeare"),
        
        // 18th-19th Century Fiction
        "GulliversTravels.epub": BookMeta(author: "Jonathan Swift", gutenbergId: "829", category: "fiction"),
        "TristramShandy.epub": BookMeta(author: "Laurence Sterne", gutenbergId: "1079", category: "fiction"),
        "TomJones.epub": BookMeta(author: "Henry Fielding", gutenbergId: "6593", category: "fiction"),
        "DonQuixote.epub": BookMeta(author: "Miguel de Cervantes", gutenbergId: "996", category: "fiction"),
        "GargantuaAndPantagruelBook1.epub": BookMeta(author: "François Rabelais", gutenbergId: "8166", category: "fiction"),
        "GargantuaAndPantagruelBook2.epub": BookMeta(author: "François Rabelais", gutenbergId: "8167", category: "fiction"),
        "GargantuaAndPantagruelBook3.epub": BookMeta(author: "François Rabelais", gutenbergId: "8168", category: "fiction"),
        "GargantuaAndPantagruelBook4.epub": BookMeta(author: "François Rabelais", gutenbergId: "8169", category: "fiction"),
        
        // Political Economy
        "TheWealthOfNations.epub": BookMeta(author: "Adam Smith", gutenbergId: "3300", category: "philosophy"),
        "TheFederalist.epub": BookMeta(author: "Hamilton, Madison, Jay", gutenbergId: "1404", category: "philosophy"),
        "OnLiberty.epub": BookMeta(author: "John Stuart Mill", gutenbergId: "421", category: "philosophy"),
        "ConsiderationsOnRepresentativeGovernment.epub": BookMeta(author: "John Stuart Mill", gutenbergId: "5669", category: "philosophy"),
        "Utilitarianism.epub": BookMeta(author: "John Stuart Mill", gutenbergId: "11224", category: "philosophy"),
        "TheCommunistManifesto.epub": BookMeta(author: "Karl Marx & Friedrich Engels", gutenbergId: "61", category: "philosophy"),
        
        // 19th-20th Century Fiction
        "MobyDick.epub": BookMeta(author: "Herman Melville", gutenbergId: "2701", category: "fiction"),
        "WarAndPeace.epub": BookMeta(author: "Leo Tolstoy", gutenbergId: "2600", category: "fiction"),
        "TheBrothersKaramazov.epub": BookMeta(author: "Fyodor Dostoevsky", gutenbergId: "28054", category: "fiction"),
        "CrimeAndPunishment.epub": BookMeta(author: "Fyodor Dostoevsky", gutenbergId: "2554", category: "fiction"),
        "AnnaKarenina.epub": BookMeta(author: "Leo Tolstoy", gutenbergId: "1399", category: "fiction"),
        "WutheringHeights.epub": BookMeta(author: "Emily Brontë", gutenbergId: "768", category: "fiction"),
        "PrideAndPrejudice.epub": BookMeta(author: "Jane Austen", gutenbergId: "1342", category: "fiction"),
        "Middlemarch.epub": BookMeta(author: "George Eliot", gutenbergId: "145", category: "fiction"),
        "GreatExpectations.epub": BookMeta(author: "Charles Dickens", gutenbergId: "1400", category: "fiction"),
        "HeartOfDarkness.epub": BookMeta(author: "Joseph Conrad", gutenbergId: "219", category: "fiction"),
        "Ulysses.epub": BookMeta(author: "James Joyce", gutenbergId: "4300", category: "fiction"),
        "Candide.epub": BookMeta(author: "Voltaire", gutenbergId: "19942", category: "fiction"),
        "Faust.epub": BookMeta(author: "Johann Wolfgang von Goethe", gutenbergId: "14591", category: "poetry"),
        "DivineComedy.epub": BookMeta(author: "Dante Alighieri", gutenbergId: "8800", category: "poetry"),
        
        // Boswell, Bacon
        "TheLifeOfSamuelJohnson.epub": BookMeta(author: "James Boswell", gutenbergId: "1564", category: "history"),
        "TheAdvancementOfLearning.epub": BookMeta(author: "Francis Bacon", gutenbergId: "5500", category: "philosophy"),
        "NovumOrganum.epub": BookMeta(author: "Francis Bacon", gutenbergId: "45988", category: "philosophy"),
        "NewAtlantis.epub": BookMeta(author: "Francis Bacon", gutenbergId: "2434", category: "fiction"),
        
        // Psychology
        "ThePrinciplesOfPsychologyVol1.epub": BookMeta(author: "William James", gutenbergId: "57628", category: "science"),
        "ThePrinciplesOfPsychologyVol2.epub": BookMeta(author: "William James", gutenbergId: "57634", category: "science"),
        "DreamPsychology.epub": BookMeta(author: "Sigmund Freud", gutenbergId: "38219", category: "science"),
        "AGeneralIntroToPsychoAnalysis.epub": BookMeta(author: "Sigmund Freud", gutenbergId: "35875", category: "science"),
        "BeyondThePleasurePrinciple.epub": BookMeta(author: "Sigmund Freud", gutenbergId: "57532", category: "science"),
        "CivilizationAndItsDiscontents.epub": BookMeta(author: "Sigmund Freud", gutenbergId: "69905", category: "science"),
    ]
}

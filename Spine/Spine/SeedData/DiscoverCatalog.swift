import Foundation
import SwiftData

// MARK: - Discover Catalog
// Lightweight catalog of 285 classic texts from Project Gutenberg.
// These appear in the Discover tab as downloadable books.
// Only title, author, and gutenbergId are seeded — full metadata
// is extracted from the EPUB after download via IngestionPipeline.

struct DiscoverCatalog {
    
    // MARK: - LibriVox Availability
    
    /// Gutenberg IDs that are verified to have LibriVox audiobook recordings.
    /// Only these should appear in the Audiobooks tab. ~23% of the catalog.
    /// Last audited: 2026-03-14
    static let knownLibriVoxIds: Set<String> = [
        "11",       // Alice's Adventures in Wonderland
        "12",       // Through the Looking-Glass
        "20",       // Paradise Lost
        "60",       // The Scarlet Pimpernel
        "62",       // A Princess of Mars
        "73",       // The Red Badge of Courage
        "76",       // Adventures of Huckleberry Finn
        "82",       // Ivanhoe
        "103",      // Around the World in Eighty Days
        "120",      // Treasure Island
        "145",      // Middlemarch
        "159",      // The Island of Doctor Moreau
        "209",      // The Turn of the Screw
        "215",      // The Call of the Wild
        "219",      // Heart of Darkness
        "271",      // Black Beauty
        "289",      // The Wind in the Willows
        "308",      // Three Men in a Boat
        "768",      // Wuthering Heights
        "829",      // Gulliver's Travels
        "996",      // Don Quixote
        "1112",     // Romeo and Juliet
        "1228",     // The Origin of Species
        "1232",     // The Prince
        "1257",     // The Three Musketeers
        "1342",     // Pride and Prejudice
        "1399",     // Anna Karenina
        "1400",     // Great Expectations
        "1497",     // The Republic
        "1514",     // A Midsummer Night's Dream
        "1515",     // The Merchant of Venice
        "1524",     // Hamlet
        "1531",     // Othello
        "1532",     // King Lear
        "1533",     // Macbeth
        "1540",     // The Tempest
        "1597",     // Andersen's Fairy Tales
        "1656",     // Apology
        "1695",     // The Man Who Was Thursday
        "1727",     // The Odyssey
        "2199",     // The Iliad
        "2383",     // The Canterbury Tales
        "2413",     // Madame Bovary
        "2542",     // A Doll's House
        "2554",     // Crime and Punishment
        "2600",     // War and Peace
        "2701",     // Moby-Dick
        "3207",     // Leviathan
        "3296",     // The Confessions
        "3300",     // The Wealth of Nations
        "3420",     // A Vindication of the Rights of Woman
        "3748",     // A Journey to the Interior of the Earth
        "4300",     // Ulysses
        "5658",     // Lord Jim
        "7142",     // History of the Peloponnesian War
        "7849",     // The Trial
        "8117",     // The Possessed
        "8800",     // Divine Comedy
        "15877",    // The Meditations (Marcus Aurelius)
        "16377",    // Antigone
        "19942",    // Candide
        "28054",    // The Brothers Karamazov
        "35875",    // A General Introduction to Psychoanalysis
    ]
    
    /// Check if a book has a known LibriVox recording.
    static func hasLibriVoxRecording(gutenbergId: String?) -> Bool {
        guard let gid = gutenbergId else { return false }
        return knownLibriVoxIds.contains(gid)
    }
    
    /// (gutenbergId, title, author)
    static let entries: [(String, String, String)] = [
        ("12", "Through the Looking-Glass", "Lewis Carroll"),
        ("20", "Paradise Lost", "John Milton"),
        ("31", "Oedipus the King", "Sophocles"),
        ("32", "Herland", "Charlotte Perkins Gilman"),
        ("59", "Meditations on First Philosophy", "René Descartes"),
        ("60", "The Scarlet Pimpernel", "Baroness Orczy"),
        ("61", "The Communist Manifesto", "Karl Marx & Friedrich Engels"),
        ("62", "A Princess of Mars", "Edgar Rice Burroughs"),
        ("73", "The Red Badge of Courage", "Stephen Crane"),
        ("76", "Adventures of Huckleberry Finn", "Mark Twain"),
        ("82", "Ivanhoe", "Sir Walter Scott"),
        ("103", "Around the World in Eighty Days", "Jules Verne"),
        ("120", "Treasure Island", "Robert Louis Stevenson"),
        ("145", "Middlemarch", "George Eliot"),
        ("159", "The Island of Doctor Moreau", "H.G. Wells"),
        ("209", "The Turn of the Screw", "Henry James"),
        ("215", "The Call of the Wild", "Jack London"),
        ("219", "Heart of Darkness", "Joseph Conrad"),
        ("227", "The Aeneid", "Virgil"),
        ("230", "Eclogues", "Virgil"),
        ("232", "Georgics", "Virgil"),
        ("257", "Troilus and Criseyde", "Geoffrey Chaucer"),
        ("271", "Black Beauty", "Anna Sewell"),
        ("289", "The Wind in the Willows", "Kenneth Grahame"),
        ("308", "Three Men in a Boat", "Jerome K. Jerome"),
        ("421", "On Liberty", "John Stuart Mill"),
        ("580", "The Pickwick Papers", "Charles Dickens"),
        ("601", "The Monk", "Matthew Lewis"),
        ("608", "Areopagitica", "John Milton"),
        ("674", "Plutarch's Lives", "Plutarch"),
        ("768", "Wuthering Heights", "Emily Brontë"),
        ("785", "On the Nature of Things", "Lucretius"),
        ("829", "Gulliver's Travels", "Jonathan Swift"),
        ("996", "Don Quixote", "Miguel de Cervantes"),
        ("1041", "Sonnets", "William Shakespeare"),
        ("1079", "Tristram Shandy", "Laurence Sterne"),
        ("1081", "Dead Souls", "Nikolai Gogol"),
        ("1112", "Romeo and Juliet", "William Shakespeare"),
        ("1200", "Gargantua and Pantagruel", "François Rabelais"),
        ("1228", "The Origin of Species", "Charles Darwin"),
        ("1232", "The Prince", "Niccolò Machiavelli"),
        ("1257", "The Three Musketeers", "Alexandre Dumas"),
        ("1322", "Leaves of Grass", "Walt Whitman"),
        ("1338", "Samson Agonistes", "John Milton"),
        ("1342", "Pride and Prejudice", "Jane Austen"),
        ("1399", "Anna Karenina", "Leo Tolstoy"),
        ("1400", "Great Expectations", "Charles Dickens"),
        ("1404", "The Federalist", "Hamilton, Madison & Jay"),
        ("1497", "The Republic", "Plato"),
        ("1500", "Henry VI, Part 1", "William Shakespeare"),
        ("1501", "Henry VI, Part 2", "William Shakespeare"),
        ("1502", "Henry VI, Part 3", "William Shakespeare"),
        ("1503", "Richard III", "William Shakespeare"),
        ("1504", "The Comedy of Errors", "William Shakespeare"),
        ("1505", "Titus Andronicus", "William Shakespeare"),
        ("1508", "The Taming of the Shrew", "William Shakespeare"),
        ("1509", "The Two Gentlemen of Verona", "William Shakespeare"),
        ("1510", "Love's Labour's Lost", "William Shakespeare"),
        ("1511", "The Life and Death of King John", "William Shakespeare"),
        ("1512", "Richard II", "William Shakespeare"),
        ("1514", "A Midsummer Night's Dream", "William Shakespeare"),
        ("1515", "The Merchant of Venice", "William Shakespeare"),
        ("1516", "Henry IV, Part 1", "William Shakespeare"),
        ("1517", "Henry IV, Part 2", "William Shakespeare"),
        ("1519", "Much Ado About Nothing", "William Shakespeare"),
        ("1521", "Henry V", "William Shakespeare"),
        ("1522", "Julius Caesar", "William Shakespeare"),
        ("1523", "As You Like It", "William Shakespeare"),
        ("1524", "Hamlet", "William Shakespeare"),
        ("1525", "The Merry Wives of Windsor", "William Shakespeare"),
        ("1526", "Twelfth Night", "William Shakespeare"),
        ("1528", "Troilus and Cressida", "William Shakespeare"),
        ("1529", "All's Well That Ends Well", "William Shakespeare"),
        ("1530", "Measure for Measure", "William Shakespeare"),
        ("1531", "Othello", "William Shakespeare"),
        ("1532", "King Lear", "William Shakespeare"),
        ("1533", "Macbeth", "William Shakespeare"),
        ("1534", "Antony and Cleopatra", "William Shakespeare"),
        ("1535", "Coriolanus", "William Shakespeare"),
        ("1536", "Timon of Athens", "William Shakespeare"),
        ("1537", "Pericles", "William Shakespeare"),
        ("1538", "Cymbeline", "William Shakespeare"),
        ("1539", "The Winter's Tale", "William Shakespeare"),
        ("1540", "The Tempest", "William Shakespeare"),
        ("1541", "Henry VIII", "William Shakespeare"),
        ("1564", "The Life of Samuel Johnson", "James Boswell"),
        ("1571", "Critias", "Plato"),
        ("1572", "Timaeus", "Plato"),
        ("1579", "Lysis", "Plato"),
        ("1580", "Charmides", "Plato"),
        ("1584", "Laches", "Plato"),
        ("1591", "Protagoras", "Plato"),
        ("1597", "Andersen's Fairy Tales", "Hans Christian Andersen"),
        ("1598", "Euthydemus", "Plato"),
        ("1600", "Symposium", "Plato"),
        ("1616", "Cratylus", "Plato"),
        ("1635", "Ion", "Plato"),
        ("1636", "Phaedrus", "Plato"),
        ("1642", "Euthyphro", "Plato"),
        ("1643", "Meno", "Plato"),
        ("1656", "Apology", "Plato"),
        ("1657", "Crito", "Plato"),
        ("1658", "Phaedo", "Plato"),
        ("1672", "Gorgias", "Plato"),
        ("1687", "Parmenides", "Plato"),
        ("1695", "The Man Who Was Thursday", "G.K. Chesterton"),
        ("1700", "Theaetetus", "Plato"),
        ("1727", "The Odyssey", "Homer"),
        ("1735", "Sophist", "Plato"),
        ("1738", "Statesman", "Plato"),
        ("1744", "Philebus", "Plato"),
        ("1750", "Laws", "Plato"),
        ("1891", "Tom Jones", "Henry Fielding"),
        ("1974", "Poetics", "Aristotle"),
        ("2160", "The Expedition of Humphry Clinker", "Tobias Smollett"),
        ("2199", "The Iliad", "Homer"),
        ("2229", "Faust", "Johann Wolfgang von Goethe"),
        ("2300", "The Descent of Man", "Charles Darwin"),
        ("2383", "The Canterbury Tales", "Geoffrey Chaucer"),
        ("2413", "Madame Bovary", "Gustave Flaubert"),
        ("2434", "New Atlantis", "Francis Bacon"),
        ("2542", "A Doll's House", "Henrik Ibsen"),
        ("2554", "Crime and Punishment", "Fyodor Dostoevsky"),
        ("2600", "War and Peace", "Leo Tolstoy"),
        ("2638", "The Idiot", "Fyodor Dostoevsky"),
        ("2680", "The Athenian Constitution", "Aristotle"),
        ("2701", "Moby-Dick", "Herman Melville"),
        ("2707", "The History of Herodotus", "Herodotus"),
        ("3011", "The Knights", "Aristophanes"),
        ("3012", "The Acharnians", "Aristophanes"),
        ("3013", "Peace", "Aristophanes"),
        ("3014", "The Birds", "Aristophanes"),
        ("3015", "The Frogs", "Aristophanes"),
        ("3160", "The Clouds", "Aristophanes"),
        ("3207", "Leviathan", "Thomas Hobbes"),
        ("3244", "Ecclesiazusae", "Aristophanes"),
        ("3296", "The Confessions", "Jean-Jacques Rousseau"),
        ("3300", "The Wealth of Nations", "Adam Smith"),
        ("3420", "A Vindication of the Rights of Woman", "Mary Wollstonecraft"),
        ("3421", "Thesmophoriazusae", "Aristophanes"),
        ("3502", "The Wasps", "Aristophanes"),
        ("3600", "Essays of Montaigne", "Michel de Montaigne"),
        ("3679", "Plutus", "Aristophanes"),
        ("3748", "A Journey to the Interior of the Earth", "Jules Verne"),
        ("3800", "Ethics", "Baruch Spinoza"),
        ("4085", "The Adventures of Roderick Random", "Tobias Smollett"),
        ("4280", "Critique of Pure Reason", "Immanuel Kant"),
        ("4300", "Ulysses", "James Joyce"),
        ("4391", "Discourse on the Method", "René Descartes"),
        ("4723", "The Principles of Human Knowledge", "George Berkeley"),
        ("5500", "The Advancement of Learning", "Francis Bacon"),
        ("5658", "Lord Jim", "Joseph Conrad"),
        ("5669", "Considerations on Representative Government", "John Stuart Mill"),
        ("5682", "Fundamental Principles of the Metaphysic of Morals", "Immanuel Kant"),
        ("5683", "Critique of Practical Reason", "Immanuel Kant"),
        ("6593", "Tom Jones", "Henry Fielding"),
        ("6740", "On the Gait of Animals", "Aristotle"),
        ("6741", "On the Motion of Animals", "Aristotle"),
        ("6742", "Parts of Animals", "Aristotle"),
        ("6743", "On the Generation of Animals", "Aristotle"),
        ("6745", "History of Animals", "Aristotle"),
        ("6747", "Physics", "Aristotle"),
        ("6748", "On the Heavens", "Aristotle"),
        ("6750", "On Generation and Corruption", "Aristotle"),
        ("6752", "On Sense and the Sensible", "Aristotle"),
        ("6753", "On the Soul", "Aristotle"),
        ("6754", "On Sleep and Sleeplessness", "Aristotle"),
        ("6755", "On Memory and Reminiscence", "Aristotle"),
        ("6756", "On Dreams", "Aristotle"),
        ("6757", "Meteorology", "Aristotle"),
        ("6758", "On Prophesying by Dreams", "Aristotle"),
        ("6759", "On Longevity and Shortness of Life", "Aristotle"),
        ("6760", "On Youth and Old Age", "Aristotle"),
        ("6761", "The Adventures of Ferdinand Count Fathom", "Tobias Smollett"),
        ("6762", "Categories", "Aristotle"),
        ("6763", "On Interpretation", "Aristotle"),
        ("6764", "Prior Analytics", "Aristotle"),
        ("6765", "Posterior Analytics", "Aristotle"),
        ("6766", "Topics", "Aristotle"),
        ("6767", "Sophistical Refutations", "Aristotle"),
        ("6867", "Nicomachean Ethics", "Aristotle"),
        ("6868", "Politics", "Aristotle"),
        ("6870", "Rhetoric", "Aristotle"),
        ("7142", "History of the Peloponnesian War", "Thucydides"),
        ("7148", "Works of Archimedes", "Archimedes"),
        ("7370", "A Letter Concerning Toleration", "John Locke"),
        ("7700", "Lysistrata", "Aristophanes"),
        ("7840", "The Trachiniae", "Sophocles"),
        ("7849", "The Trial", "Franz Kafka"),
        ("7927", "Oedipus at Colonus", "Sophocles"),
        ("8117", "The Possessed", "Fyodor Dostoevsky"),
        ("8166", "Gargantua and Pantagruel, Book 1", "François Rabelais"),
        ("8167", "Gargantua and Pantagruel, Book 2", "François Rabelais"),
        ("8168", "Gargantua and Pantagruel, Book 3", "François Rabelais"),
        ("8169", "Gargantua and Pantagruel, Book 4", "François Rabelais"),
        ("8438", "Metaphysics", "Aristotle"),
        ("8501", "Cyclops", "Euripides"),
        ("8502", "Philoctetes", "Sophocles"),
        ("8503", "Iphigenia in Tauris", "Euripides"),
        ("8504", "Iphigenia in Aulis", "Euripides"),
        ("8505", "Orestes", "Euripides"),
        ("8506", "The Phoenician Women", "Euripides"),
        ("8507", "Heracles Mad", "Euripides"),
        ("8508", "Bacchantes", "Euripides"),
        ("8509", "Electra", "Euripides"),
        ("8510", "Hecuba", "Euripides"),
        ("8511", "Helen", "Euripides"),
        ("8512", "Ion", "Euripides"),
        ("8513", "Heracleidae", "Euripides"),
        ("8514", "Andromache", "Euripides"),
        ("8515", "The Suppliants", "Euripides"),
        ("8516", "Rhesus", "Euripides"),
        ("8580", "The Trojan Women", "Euripides"),
        ("8618", "Choephoroe", "Aeschylus"),
        ("8619", "The Eumenides", "Aeschylus"),
        ("8676", "The Suppliant Maidens", "Aeschylus"),
        ("8677", "The Persians", "Aeschylus"),
        ("8678", "Seven Against Thebes", "Aeschylus"),
        ("8714", "Prometheus Bound", "Aeschylus"),
        ("8788", "Ajax", "Sophocles"),
        ("8800", "Divine Comedy", "Dante Alighieri"),
        ("9256", "On Christian Doctrine", "Saint Augustine"),
        ("9662", "An Enquiry Concerning Human Understanding", "David Hume"),
        ("10523", "Alcestis", "Euripides"),
        ("10615", "An Essay Concerning Human Understanding", "John Locke"),
        ("10661", "The Discourses of Epictetus", "Epictetus"),
        ("11136", "A Discourse on Inequality", "Jean-Jacques Rousseau"),
        ("11224", "Utilitarianism", "John Stuart Mill"),
        ("14078", "Experimental Researches in Electricity", "Michael Faraday"),
        ("14417", "Agamemnon", "Aeschylus"),
        ("14484", "Electra", "Sophocles"),
        ("14591", "Faust", "Johann Wolfgang von Goethe"),
        ("14725", "Treatise on Light", "Christiaan Huygens"),
        ("14990", "Hippolytus", "Euripides"),
        ("15877", "The Meditations", "Marcus Aurelius"),
        ("16377", "Antigone", "Sophocles"),
        ("16927", "The Histories", "Tacitus"),
        ("17611", "Summa Theologica, Part 1", "Thomas Aquinas"),
        ("17897", "Summa Theologica, Part 2a", "Thomas Aquinas"),
        ("18121", "Works of Hippocrates", "Hippocrates"),
        ("18269", "Pensées", "Blaise Pascal"),
        ("18755", "Summa Theologica, Part 2b", "Thomas Aquinas"),
        ("19315", "The Poems of Giacomo Leopardi", "Giacomo Leopardi"),
        ("19773", "Summa Theologica, Supplement", "Thomas Aquinas"),
        ("19942", "Candide", "Voltaire"),
        ("19950", "Summa Theologica, Part 3", "Thomas Aquinas"),
        ("21076", "Elements", "Euclid"),
        ("21765", "The Metamorphoses, Books I–VII", "Ovid"),
        ("23700", "The Decameron", "Giovanni Boccaccio"),
        ("25717", "The Decline and Fall of the Roman Empire", "Edward Gibbon"),
        ("27573", "The Spirit of the Laws", "Montesquieu"),
        ("28054", "The Brothers Karamazov", "Fyodor Dostoevsky"),
        ("28233", "On the Motion of the Heart and Blood", "William Harvey"),
        ("30775", "Elements of Chemistry", "Antoine Lavoisier"),
        ("33228", "On the Loadstone", "William Gilbert"),
        ("33504", "Opticks", "Isaac Newton"),
        ("35451", "Medea", "Euripides"),
        ("35875", "A General Introduction to Psychoanalysis", "Sigmund Freud"),
        ("37729", "Dialogues Concerning Two New Sciences", "Galileo Galilei"),
        ("38219", "Dream Psychology", "Sigmund Freud"),
        ("43383", "On the Natural Faculties", "Galen"),
        ("45304", "The City of God, Vol. 1", "Saint Augustine"),
        ("45305", "The City of God, Vol. 2", "Saint Augustine"),
        ("45988", "Novum Organum", "Francis Bacon"),
        ("46333", "The Social Contract", "Jean-Jacques Rousseau"),
        ("48433", "The Critique of Judgement", "Immanuel Kant"),
        ("49447", "The Six Enneads", "Plotinus"),
        ("51635", "The Philosophy of History", "Georg Wilhelm Friedrich Hegel"),
        ("57532", "Beyond the Pleasure Principle", "Sigmund Freud"),
        ("57628", "The Principles of Psychology, Vol. 1", "William James"),
        ("57634", "The Principles of Psychology, Vol. 2", "William James"),
        ("69905", "Civilization and Its Discontents", "Sigmund Freud"),
        ("73959", "The Provincial Letters", "Blaise Pascal"),
    ]
    
    /// Seed all discover catalog entries as downloadable (not yet downloaded) books.
    /// Skips any books whose gutenbergId already exists in the database.
    static func seedIfNeeded(modelContext: ModelContext) {
        // Fetch existing gutenberg IDs to avoid duplicates
        let descriptor = FetchDescriptor<Book>()
        let existingBooks = (try? modelContext.fetch(descriptor)) ?? []
        let existingIds = Set(existingBooks.compactMap(\.gutenbergId))
        
        var inserted = 0
        for (gid, title, author) in entries {
            guard !existingIds.contains(gid) else { continue }
            
            let book = Book(
                title: title,
                author: author,
                sourceType: .gutenberg,
                gutenbergId: gid
            )
            book.importStatus = .pending
            book.isDownloaded = false
            
            modelContext.insert(book)
            inserted += 1
        }
        
        if inserted > 0 {
            try? modelContext.save()
            print("📚 Discover catalog: seeded \(inserted) new books (\(entries.count - inserted) already existed)")
        }
    }
}

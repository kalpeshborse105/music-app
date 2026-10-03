/// Media kind. Version 1 only ships AUDIO, but the model is future-proof so a
/// video layer can be added without reshaping the catalogue or player service.
enum MediaType {
  audio,
  video,
}

/// Sezóna končí 31. října. Listopad a prosinec patří už do sezóny dalšího roku.
int seasonEndingYear(DateTime date) {
  return date.month >= 11 ? date.year + 1 : date.year;
}

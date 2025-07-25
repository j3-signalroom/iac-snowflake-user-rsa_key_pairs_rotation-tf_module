
# This controls each key's rotations
resource "time_rotating" "rsa_key_pair_rotations" {
    count         = local.key_pairs_to_retain
    rotation_days = var.day_count*local.key_pairs_to_retain
    rfc3339       = timeadd(local.now, format("-%sh", (count.index)*local.hour_count))
}

# Store the retain RSA key pairs and the time when the rotation needs to accord.  In order, to 
# trigger a `replace_triggered_by` on the RSA key pair.  Refer to GitHub Issue for more info
# https://github.com/hashicorp/terraform-provider-time/issues/118
resource "time_static" "rsa_key_pair_rotations" {
    count   = local.key_pairs_to_retain
    rfc3339 = time_rotating.rsa_key_pair_rotations[count.index].rfc3339
}
